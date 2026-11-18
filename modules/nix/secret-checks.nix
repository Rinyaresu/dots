{ config, ... }:
{
  perSystem =
    { pkgs, ... }:
    let
      system = config.flake.nixosConfigurations.desktop.config;
      home = system.home-manager.users.rinyaresu;
      secret = system.sops.secrets.rinyaresu-ssh-key;
      inherit (config.flake.modules) nixos homeManager;
    in
    {
      packages.secret-runtime = import ../../checks/secret-runtime.nix {
        inherit nixos homeManager pkgs;
      };
      packages.bootstrap-runtime = import ../../checks/bootstrap-runtime.nix {
        inherit nixos homeManager pkgs;
      };
      checks.secret-build-boundary =
        assert
          system.sops.validateSopsFiles
          && secret.sopsFile == ../../secrets/ssh.yaml
          && !(builtins.hasContext system.sops.age.keyFile)
          && !system.sops.age.generateKey
          && system.sops.age.sshKeyPaths == [ ]
          && system.sops.gnupg.sshKeyPaths == [ ]
          && builtins.elem "sops-install-secrets.service" system.systemd.services.home-manager-rinyaresu.requires;
        pkgs.runCommand "secret-build-boundary" { nativeBuildInputs = [ pkgs.python3 ]; } ''
          export HOME="$TMPDIR/empty-home"
          mkdir -p "$HOME"
          test -x ${home.home.activationPackage}/activate
          python3 - ${system.system.build.sops-nix-manifest} \
            ${home.home.file.".ssh/id_ed25519".source} ${secret.sopsFile} <<'PY'
          import json
          import os
          import pathlib
          import sys

          assert not pathlib.Path("/var/lib/sops-nix/key.txt").exists()
          assert not pathlib.Path("/var/lib/sops-nix/ssh.yaml").exists()
          assert not (pathlib.Path.home() / "personal/home").exists()
          manifest = json.loads(pathlib.Path(sys.argv[1]).read_text())
          assert manifest["ageKeyFile"] == "/var/lib/sops-nix/key.txt"
          assert len(manifest["secrets"]) == 1
          secret = manifest["secrets"][0]
          assert secret["sopsFile"] == sys.argv[3]
          assert pathlib.Path(secret["sopsFile"]).is_file()
          assert secret["sopsFile"].startswith("/nix/store/")
          assert secret["key"] == "ssh_private_key"
          assert secret["owner"] == "rinyaresu"
          assert secret["mode"] == "0600"
          assert os.readlink(sys.argv[2]) == "/run/secrets/rinyaresu-ssh-key"
          PY
          touch "$out"
        '';
    };
}
