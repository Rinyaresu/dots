{ config, lib, ... }:
{
  perSystem =
    { pkgs, ... }:
    let
      runtime = import ../../checks/secret-runtime.nix {
        nixos = config.flake.modules.nixos;
        homeManager = config.flake.modules.homeManager;
        inherit pkgs;
      };
      system = runtime.config.nodes.machine;
      home = system.home-manager.users.rinyaresu;
      secret = system.sops.secrets.rinyaresu-ssh-key;
      results = {
        ciphertext-is-declared-source =
          builtins.isPath secret.sopsFile && secret.sopsFile == ../../secrets/ssh.yaml;
        identity-is-runtime-string =
          system.sops.age.keyFile == "/var/lib/sops-nix/key.txt"
          && !(builtins.hasContext system.sops.age.keyFile);
        build-time-ciphertext-validation = system.sops.validateSopsFiles;
        no-generated-identity = !system.sops.age.generateKey;
        no-host-key-fallback = system.sops.age.sshKeyPaths == [ ] && system.sops.gnupg.sshKeyPaths == [ ];
        no-personal-bootstrap = !(home.systemd.user.services ? pi-config-restore);
      };
      failures = builtins.attrNames (lib.filterAttrs (_: pass: !pass) results);
    in
    {
      checks.secret-runtime = runtime;
      checks.bootstrap-runtime = import ../../checks/bootstrap-runtime.nix {
        nixos = config.flake.modules.nixos;
        homeManager = config.flake.modules.homeManager;
        inherit pkgs;
      };
      checks.secret-build-boundary =
        assert lib.assertMsg (
          failures == [ ]
        ) "Secret build boundary failures: ${lib.concatStringsSep ", " failures}";
        pkgs.runCommand "secret-build-boundary" { nativeBuildInputs = [ pkgs.python3 ]; } ''
          export HOME="$TMPDIR/empty-home"
          mkdir -p "$HOME"
          test -x ${system.system.build.toplevel}/init
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
          cat > "$out" <<'JSON'
          ${builtins.toJSON results}
          JSON
        '';
    };
}
