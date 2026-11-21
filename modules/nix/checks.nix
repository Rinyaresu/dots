{ config, ... }:
let
  desktop = config.flake.nixosConfigurations.desktop.config;
  home = desktop.home-manager.users.rinyaresu;
  restoreScript = builtins.head home.systemd.user.services.pi-config-restore.Service.ExecStart;
  pi = builtins.head (builtins.filter (package: (package.pname or "") == "pi") home.home.packages);
in
{
  perSystem = { pkgs, ... }: {
    checks.pi-bootstrap-restore = pkgs.runCommand "pi-bootstrap-restore-check" { } ''
      set -euo pipefail
      mkdir -p "$TMPDIR/stubs"
      cat > "$TMPDIR/stubs/ssh-add" <<'EOF'
      #!${pkgs.runtimeShell}
      printf '256 SHA256:bootstrap-fixture fixture (ED25519)\n'
      EOF
      cat > "$TMPDIR/stubs/ssh-keygen" <<'EOF'
      #!${pkgs.runtimeShell}
      printf '256 SHA256:bootstrap-fixture fixture (ED25519)\n'
      EOF
      cat > "$TMPDIR/stubs/git" <<'EOF'
      #!${pkgs.runtimeShell}
      set -euo pipefail
      [[ "$1" == clone && "$GIT_TERMINAL_PROMPT" == 0 ]]
      [[ "$GIT_SSH_COMMAND" == *StrictHostKeyChecking=yes* && "$GIT_SSH_COMMAND" == *BatchMode=yes* ]]
      branch="$4"
      repository="$5"
      destination="$6"
      printf '%s %s\n' "$repository" "$branch" >> "$HOME/clones"
      if [[ "$repository" == "''${FAIL_REPOSITORY:-}" ]]; then
        exit 32
      fi
      case "$repository" in
        git@github.com:Rinyaresu/home.git) race="$RACE_HOME" ;;
        git@github.com:Rinyaresu/agent.git) race="$RACE_PI" ;;
        *) exit 30 ;;
      esac
      if [[ -n "$race" ]]; then
        if [[ "$repository" == git@github.com:Rinyaresu/agent.git && -n "''${RACE_PI_LINK:-}" ]]; then
          ln -s "$RACE_PI_LINK" "$race"
        else
          mkdir -p "$race"
          printf preserved > "$race/marker"
          if [[ "$repository" == git@github.com:Rinyaresu/home.git && "''${INVALID_RACE_HOME:-0}" == 0 ]]; then
            mkdir -p "$race/references"
            printf valid > "$race/references/personal.md"
          fi
        fi
      fi
      mkdir -p "$destination"
      printf clone > "$destination/marker"
      if [[ "$repository" == git@github.com:Rinyaresu/home.git ]]; then
        mkdir -p "$destination/references"
        printf valid > "$destination/references/personal.md"
      fi
      EOF
      chmod +x "$TMPDIR/stubs/ssh-add" "$TMPDIR/stubs/ssh-keygen" "$TMPDIR/stubs/git"
      substitute ${restoreScript} "$TMPDIR/restore" \
        --replace-fail '${pkgs.git}/bin/git' "$TMPDIR/stubs/git" \
        --replace-fail '${pkgs.openssh}/bin/ssh-add' "$TMPDIR/stubs/ssh-add" \
        --replace-fail '${pkgs.openssh}/bin/ssh-keygen' "$TMPDIR/stubs/ssh-keygen"
      chmod +x "$TMPDIR/restore"

      export PATH="$TMPDIR/stubs:$PATH" RACE_HOME= RACE_PI= RACE_PI_LINK= FAIL_REPOSITORY= INVALID_RACE_HOME=0
      export HOME="$TMPDIR/both"
      mkdir -p "$HOME"
      "$TMPDIR/restore"
      [[ "$(cat "$HOME/clones")" == $'git@github.com:Rinyaresu/home.git main\ngit@github.com:Rinyaresu/agent.git main' ]]
      [[ -f "$HOME/personal/home/marker" && -f "$HOME/.pi/marker" ]]

      export HOME="$TMPDIR/agent-exists"
      mkdir -p "$HOME/.pi"
      printf existing > "$HOME/.pi/marker"
      "$TMPDIR/restore"
      [[ "$(cat "$HOME/clones")" == 'git@github.com:Rinyaresu/home.git main' ]]
      [[ "$(cat "$HOME/.pi/marker")" == existing ]]
      [[ -f "$HOME/personal/home/marker" ]]

      export HOME="$TMPDIR/home-exists"
      mkdir -p "$HOME/personal/home"
      printf existing > "$HOME/personal/home/marker"
      mkdir -p "$HOME/personal/home/references"
      printf valid > "$HOME/personal/home/references/personal.md"
      "$TMPDIR/restore"
      [[ "$(cat "$HOME/clones")" == 'git@github.com:Rinyaresu/agent.git main' ]]
      [[ "$(cat "$HOME/personal/home/marker")" == existing ]]
      [[ -f "$HOME/.pi/marker" ]]

      export HOME="$TMPDIR/home-symlink" RACE_HOME= RACE_PI=
      mkdir -p "$HOME/personal/checkout"
      mkdir -p "$HOME/personal/checkout/references"
      printf valid > "$HOME/personal/checkout/references/personal.md"
      ln -s checkout "$HOME/personal/home"
      "$TMPDIR/restore"
      [[ "$(cat "$HOME/clones")" == 'git@github.com:Rinyaresu/agent.git main' ]]
      [[ -L "$HOME/personal/home" && -f "$HOME/personal/home/references/personal.md" ]]

      export HOME="$TMPDIR/races" RACE_HOME="$TMPDIR/races/personal/home" RACE_PI="$TMPDIR/races/.pi"
      mkdir -p "$HOME"
      "$TMPDIR/restore"
      [[ "$(cat "$HOME/personal/home/marker")" == preserved ]]
      [[ "$(cat "$HOME/.pi/marker")" == preserved ]]
      [[ -f "$HOME/personal/home/references/personal.md" ]]

      export HOME="$TMPDIR/home-invalid" RACE_HOME= RACE_PI=
      mkdir -p "$HOME/personal/home" "$HOME/.pi"
      printf leave-alone > "$HOME/personal/home/unrelated"
      if "$TMPDIR/restore"; then
        exit 31
      fi
      [[ ! -e "$HOME/clones" ]]
      [[ -f "$HOME/personal/home/unrelated" && ! -e "$HOME/personal/home/references/personal.md" ]]
      export HOME="$TMPDIR/race-invalid" RACE_HOME="$TMPDIR/race-invalid/personal/home" RACE_PI= INVALID_RACE_HOME=1
      mkdir -p "$HOME"
      if "$TMPDIR/restore"; then
        exit 33
      fi
      [[ "$(cat "$HOME/personal/home/marker")" == preserved ]]
      [[ ! -e "$HOME/.pi" ]]

      export HOME="$TMPDIR/clone-fails" RACE_HOME= RACE_PI= FAIL_REPOSITORY=git@github.com:Rinyaresu/home.git
      mkdir -p "$HOME"
      if "$TMPDIR/restore"; then
        exit 34
      fi
      [[ ! -e "$HOME/personal/home" && ! -e "$HOME/.pi" ]]
      [[ -z "$(find "$HOME" -maxdepth 1 -name '.pi-restore.*' -print -quit)" ]]
      export HOME="$TMPDIR/pi-symlink" RACE_HOME= RACE_PI= FAIL_REPOSITORY=
      mkdir -p "$HOME"
      ln -s missing-agent "$HOME/.pi"
      "$TMPDIR/restore"
      [[ "$(cat "$HOME/clones")" == 'git@github.com:Rinyaresu/home.git main' ]]
      [[ -L "$HOME/.pi" && "$(readlink "$HOME/.pi")" == missing-agent ]]

      export HOME="$TMPDIR/race-pi-symlink" RACE_PI="$TMPDIR/race-pi-symlink/.pi" RACE_PI_LINK=preserved-link-target
      mkdir -p "$HOME"
      "$TMPDIR/restore"
      [[ -L "$HOME/.pi" && "$(readlink "$HOME/.pi")" == preserved-link-target ]]
      [[ ! -e "$HOME/preserved-link-target" ]]
      PATH=${pkgs.util-linux}/bin:$PATH bash ${../../checks/bootstrap-dependencies.sh} "$TMPDIR/restore" ${pkgs.nodejs_24}/bin \
        ${pi}/bin/pi ${../../checks/pi-local-extension-check.mjs} \
        ${../../checks/bootstrap-dependency-fixture.sh}
      touch "$out"
    '';
  };
}
