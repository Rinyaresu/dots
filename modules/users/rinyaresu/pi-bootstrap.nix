{ config, ... }:
{
  flake.modules.nixos.pi-bootstrap = {
    key = "${__curPos.file}#nixos.pi-bootstrap";
    imports = [ config.flake.modules.nixos.ssh-agent ];
    programs.ssh.knownHosts."github.com".publicKey =
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOMqqnkVzrm0SdG6UOoqKLsabgH5C9okWi0dh2l9GKJl";
  };

  flake.modules.homeManager.pi-bootstrap =
    { osConfig, pkgs, ... }:
    let
      restore = pkgs.writeShellScript "pi-config-restore" ''
        set -euo pipefail
        umask 077
        export GIT_TERMINAL_PROMPT=0
        export GIT_SSH_COMMAND="${pkgs.openssh}/bin/ssh -o BatchMode=yes -o StrictHostKeyChecking=yes -o ForwardAgent=no -o ConnectTimeout=10 -o ConnectionAttempts=1"

        if [[ -e "$HOME/personal/home" || -L "$HOME/personal/home" ]]; then
          if [[ ! -f "$HOME/personal/home/references/personal.md" ]]; then
            echo "Pi: ~/personal/home existe, mas references/personal.md está ausente; destino preservado." >&2
            exit 1
          fi
        fi
        if [[ -e "$HOME/personal/home" || -L "$HOME/personal/home" ]] \
          && [[ -e "$HOME/.pi" || -L "$HOME/.pi" ]]; then
          echo "Pi: Home e ~/.pi já existem; nenhum arquivo foi alterado."
          exit 0
        fi

        while true; do
          if ${pkgs.openssh}/bin/ssh-add -l >/dev/null 2>&1; then
            break
          fi
          ${pkgs.coreutils}/bin/sleep 5
        done

        work=$(${pkgs.coreutils}/bin/mktemp -d "$HOME/.pi-restore.XXXXXX")
        trap '${pkgs.coreutils}/bin/rm -rf -- "$work"' EXIT
        trap 'exit 143' TERM
        trap 'exit 130' INT

        restore_repo() {
          local destination="$1" repository="$2" branch="$3" label="$4"
          if [[ -e "$destination" || -L "$destination" ]]; then
            echo "Pi: $label já existe; nenhum arquivo foi alterado."
            return 0
          fi
          ${pkgs.coreutils}/bin/mkdir -p -- "$(dirname -- "$destination")"
          ${pkgs.git}/bin/git clone --single-branch --branch "$branch" \
            "$repository" "$work/$label"
          ${pkgs.coreutils}/bin/mv -T -n -- "$work/$label" "$destination"
          if [[ -e "$work/$label" || -L "$work/$label" ]]; then
            echo "Pi: $destination apareceu durante a restauração; destino preservado."
            ${pkgs.coreutils}/bin/rm -rf -- "$work/$label"
          else
            echo "Pi: $label restaurado em $destination (branch $branch)."
          fi
        }

        restore_repo "$HOME/personal/home" git@github.com:Rinyaresu/home.git main home
        if [[ ! -f "$HOME/personal/home/references/personal.md" ]]; then
          echo "Pi: ~/personal/home não contém references/personal.md; destino preservado." >&2
          exit 1
        fi
        restore_repo "$HOME/.pi" git@github.com:Rinyaresu/agent.git main agent
      '';
    in
    {
      key = "${__curPos.file}#homeManager.pi-bootstrap";
      imports = [ config.flake.modules.homeManager.pi ];
      assertions = [
        {
          assertion =
            osConfig.programs.ssh.startAgent
            &&
              (osConfig.programs.ssh.knownHosts."github.com".publicKey or null)
              == "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOMqqnkVzrm0SdG6UOoqKLsabgH5C9okWi0dh2l9GKJl";
          message = "Pi bootstrap requires the native SSH agent and the pinned GitHub host key.";
        }
      ];
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
