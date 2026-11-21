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
      provision = pkgs.writeShellScript "pi-extension-deps" (
        "export PATH=${
          pkgs.lib.makeBinPath [
            pkgs.nodejs_24
            pkgs.coreutils
            pkgs.diffutils
          ]
        }"
        + "\n"
        + builtins.readFile ./_pi-extension-deps.sh
      );
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
          exec ${provision}
        fi

        unlock=waiting
        while true; do
          agent_status=0
          identities=$(${pkgs.openssh}/bin/ssh-add -E sha256 -l 2>/dev/null) || agent_status=$?
          case "$agent_status" in
            0|1)
              key_info=$(${pkgs.openssh}/bin/ssh-keygen -E sha256 -lf "$HOME/.ssh/id_ed25519" </dev/null 2>/dev/null) || key_info=
              read -r _ fingerprint _ <<< "$key_info"
              if [[ -n "$fingerprint" ]]; then
                while read -r _ loaded _; do
                  if [[ "$loaded" == "$fingerprint" ]]; then
                    break 2
                  fi
                done <<< "$identities"
              fi
              if [[ "$unlock" == waiting && -n "$fingerprint" ]]; then
                unset DISPLAY WAYLAND_DISPLAY XAUTHORITY
                while IFS='=' read -r name value; do
                  case "$name" in
                    DISPLAY|WAYLAND_DISPLAY|XAUTHORITY) export "$name=$value" ;;
                  esac
                done < <(${pkgs.systemd}/bin/systemctl --user show-environment)
                if [[ -n "''${DISPLAY:-}''${WAYLAND_DISPLAY:-}" && -r "$HOME/.ssh/id_ed25519" ]]; then
                  unlock=requested
                  if ! ${pkgs.openssh}/bin/ssh-add "$HOME/.ssh/id_ed25519" </dev/null; then
                    echo "Pi: desbloqueio cancelado ou indisponível; aguardando a identidade provisionada no agente." >&2
                  fi
                fi
              fi
              ;;
          esac
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
        ${provision}
      '';
    in
    {
      key = "${__curPos.file}#homeManager.pi-bootstrap";
      imports = [ config.flake.modules.homeManager.pi ];
      assertions = [
        {
          assertion =
            osConfig.programs.ssh.startAgent
            && osConfig.programs.ssh.enableAskPassword
            && !osConfig.services.gnome.gcr-ssh-agent.enable
            &&
              (osConfig.programs.ssh.knownHosts."github.com".publicKey or null)
              == "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOMqqnkVzrm0SdG6UOoqKLsabgH5C9okWi0dh2l9GKJl";
          message = "Pi bootstrap requires the native SSH agent and the pinned GitHub host key.";
        }
      ];
      home.packages = [
        (pkgs.writeShellScriptBin "desktop-first-boot-check" ''
          set -euo pipefail
          export PATH="$PATH:${
            pkgs.lib.makeBinPath [
              pkgs.coreutils
              pkgs.systemd
            ]
          }"
          for unit in sops-install-secrets.service home-manager-$(id -un).service; do
            systemctl is-active --quiet "$unit" || { echo "$unit não está ativo; consulte o journal." >&2; exit 1; }
            echo "$unit: ativo"
          done
          test -s "$HOME/.ssh/id_ed25519" && test -r "$HOME/.ssh/id_ed25519" || {
            echo 'Identidade SSH provisionada pelo SOPS ausente ou ilegível.' >&2; exit 1;
          }
          systemctl --user is-active --quiet pi-config-restore.service &&
            test "$(systemctl --user show -p SubState --value pi-config-restore.service)" = exited || {
            echo 'pi-config-restore.service ainda não concluiu; use journalctl --user -u pi-config-restore.service.' >&2; exit 1;
          }
          test -f "$HOME/personal/home/references/personal.md"
          command -v efibootmgr
          pi_bin=$(realpath -- "$(command -v pi)")
          "$pi_bin" --version
          agent_dir=$(realpath -- "''${PI_CODING_AGENT_DIR:-$HOME/.pi/agent}")
          scratch=$(mktemp -d)
          trap 'rm -rf -- "$scratch"' EXIT
          # Run the loader with disposable state and no inherited account settings.
          env -i HOME="$scratch" PATH=${pkgs.lib.makeBinPath [ pkgs.nodejs_24 ]} \
            PI_CODING_AGENT_DIR="$scratch" PI_OFFLINE=1 \
            node ${./_pi-local-extension-check.mjs} "$pi_bin" "$agent_dir" "$scratch"
        '')
      ];
      systemd.user.services.pi-config-restore = {
        Unit = {
          Description = "Restore Pi configuration and local extension dependencies";
          After = [ "ssh-agent.service" ];
          Wants = [ "ssh-agent.service" ];
          StartLimitIntervalSec = 0;
        };
        Service = {
          Type = "simple";
          ExecStart = "${restore}";
          Environment = [
            "SSH_AUTH_SOCK=%t/ssh-agent"
            "SSH_ASKPASS=${osConfig.programs.ssh.askPassword}"
            "SSH_ASKPASS_REQUIRE=force"
          ];
          Restart = "on-failure";
          RestartSec = 30;
          RemainAfterExit = true;
          TimeoutStopSec = 15;
          UMask = "0077";
        };
        Install.WantedBy = [ "default.target" ];
      };
    };

  flake.modules.nixos.desktop-personal = {
    imports = [ config.flake.modules.nixos.pi-bootstrap ];
  };
  flake.modules.homeManager.desktop-personal = {
    imports = [ config.flake.modules.homeManager.pi-bootstrap ];
  };
}
