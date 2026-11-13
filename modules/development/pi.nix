{ inputs, ... }:
{
  flake.modules.homeManager.development = { pkgs, ... }: {
    home.packages = [
      (inputs.pi.packages.${pkgs.stdenv.hostPlatform.system}.default.override {
        nodejs_22 = pkgs.nodejs_24;
        importNpmLock = pkgs.importNpmLock // {
          importNpmLock =
            args:
            pkgs.importNpmLock (
              args
              // pkgs.lib.optionalAttrs (args ? packageSourceOverrides) {
                packageSourceOverrides = args.packageSourceOverrides // {
                  "node_modules/@earendil-works/pi-schema" = pkgs.fetchurl {
                    url = "https://registry.npmjs.org/@earendil-works/pi-schema/-/pi-schema-1.5.0.tgz";
                    hash = "sha512-RW0MbT2tR65OY6xMsgB/yVBb7m/RTNwA+9hurSN1vVXfHZRVmVnXbruBPrx/PzbrQnW5yLVlMRWxErGDQtF1Hg==";
                  };
                };
              }
            );
        };
      })
    ];
    home.sessionVariables.PI_NODE_BIN = "${pkgs.nodejs_24}/bin/node";
  };

  flake.modules.nixos.pi-bootstrap = {
    programs.ssh.knownHosts."github.com".publicKey =
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOMqqnkVzrm0SdG6UOoqKLsabgH5C9okWi0dh2l9GKJl";
  };

  flake.modules.homeManager.pi-bootstrap =
    { pkgs, ... }:
    let
      restore = pkgs.writeShellScript "pi-config-restore" ''
        set -euo pipefail
        umask 077
        export GIT_TERMINAL_PROMPT=0
        export GIT_SSH_COMMAND="${pkgs.openssh}/bin/ssh -o BatchMode=yes -o StrictHostKeyChecking=yes -o ForwardAgent=no -o ConnectTimeout=10 -o ConnectionAttempts=1"

        while true; do
          if [[ -e "$HOME/.pi" || -L "$HOME/.pi" ]]; then
            echo "Pi: ~/.pi já existe; nenhum arquivo foi alterado."
            exit 0
          fi
          if ${pkgs.openssh}/bin/ssh-add -l >/dev/null 2>&1; then
            break
          fi
          ${pkgs.coreutils}/bin/sleep 5
        done

        work=$(${pkgs.coreutils}/bin/mktemp -d "$HOME/.pi-restore.XXXXXX")
        trap '${pkgs.coreutils}/bin/rm -rf -- "$work"' EXIT
        trap 'exit 143' TERM
        trap 'exit 130' INT

        ${pkgs.git}/bin/git clone --single-branch --branch experimentos \
          git@github.com:Rinyaresu/agent.git "$work/repo"

        ${pkgs.coreutils}/bin/mv -T -n -- "$work/repo" "$HOME/.pi"
        if [[ -d "$work/repo" ]]; then
          echo "Pi: ~/.pi apareceu durante a restauração; destino preservado."
          exit 0
        fi
        echo "Pi: configuração restaurada em ~/.pi (branch experimentos)."
      '';
    in
    {
      systemd.user.services.pi-config-restore = {
        Unit = {
          Description = "Restore Pi configuration after explicit SSH key loading";
          After = [ "ssh-agent.service" ];
          Wants = [ "ssh-agent.service" ];
          StartLimitIntervalSec = 0;
        };
        Service = {
          Type = "simple";
          ExecStart = "${restore}";
          Environment = [ "SSH_AUTH_SOCK=%t/ssh-agent" ];
          Restart = "on-failure";
          RestartSec = 30;
          RemainAfterExit = true;
          TimeoutStopSec = 15;
          UMask = "0077";
        };
        Install.WantedBy = [ "default.target" ];
      };
    };
}
