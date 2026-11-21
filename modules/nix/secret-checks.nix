{ config, lib, ... }:
{
  perSystem =
    { pkgs, ... }:
    let
      inherit (config.flake) nixosConfigurations;
      system = nixosConfigurations.desktop.config;
      ciphertext = ../../modules/system/users/rinyaresu/ssh/secrets.yaml;
      noPersonalSSH =
        host:
        let
          cfg = nixosConfigurations.${host}.config;
          files = cfg.home-manager.users.rinyaresu.home.file or { };
        in
        (cfg.sops.secrets or { }) == { }
        && !(cfg.systemd.services ? sops-install-secrets)
        && !(files ? ".ssh/id_ed25519");
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
          && secret.sopsFile == ciphertext
          && !(builtins.hasContext system.sops.age.keyFile)
          && !system.sops.age.generateKey
          && system.sops.age.sshKeyPaths == [ ]
          && system.sops.gnupg.sshKeyPaths == [ ]
          && builtins.elem "sops-install-secrets.service" system.systemd.services.home-manager-rinyaresu.requires;
        pkgs.runCommand "secret-build-boundary"
          {
            nativeBuildInputs = [ (pkgs.python3.withPackages (ps: [ ps.pyyaml ])) ];
          }
          ''
            export HOME="$TMPDIR/empty-home"
            mkdir -p "$HOME"
            test -x ${home.home.activationPackage}/activate
            python3 - ${system.system.build.sops-nix-manifest} \
              ${home.home.file.".ssh/id_ed25519".source} ${secret.sopsFile} ${../../.sops.yaml} <<'PY'
            import json
            import os
            import pathlib
            import re
            import sys

            import yaml

            document = yaml.safe_load(pathlib.Path(sys.argv[3]).read_text())
            assert document.keys() == {"ssh_private_key", "sops"}
            assert document["ssh_private_key"].startswith("ENC[AES256_GCM,")
            metadata = document["sops"]
            # No alternative key backend or additional age recipient.
            assert metadata.keys() == {"age", "lastmodified", "mac", "unencrypted_suffix", "version"}
            recipients = [entry["recipient"] for entry in metadata["age"]]
            assert len(recipients) == 1
            rules = yaml.safe_load(pathlib.Path(sys.argv[4]).read_text())["creation_rules"]
            path = "modules/system/users/rinyaresu/ssh/secrets.yaml"
            matches = [rule for rule in rules if re.search(rule.get("path_regex", ""), path)]
            assert matches == [{"path_regex": "^" + re.escape(path) + "$", "age": recipients[0]}]

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
            assert secret["group"] == "users"
            assert secret["mode"] == "0600"
            assert os.readlink(sys.argv[2]) == "/run/secrets/rinyaresu-ssh-key"
            PY
            touch "$out"
          '';

      # Check the composed machines, not a mock or a list of their imports.
      checks.secret-host-isolation =
        assert lib.assertMsg (noPersonalSSH "lab") "Lab must not provision the personal SSH identity.";
        assert lib.assertMsg (noPersonalSSH "ordis") "Ordis must not provision the personal SSH identity.";
        pkgs.runCommand "secret-host-isolation" { } "touch $out";
    };
}
