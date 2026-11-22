{ config, ... }:
let
  home = config.flake.nixosConfigurations.desktop.config.home-manager.users.rinyaresu;
  conf = name: home.xdg.configFile.${name}.source;
in
{
  perSystem = { pkgs, ... }: {
    checks.windows-command =
      pkgs.runCommand "windows-command-check" { nativeBuildInputs = [ pkgs.gawk ]; }
        ''
          substitute ${../system/boot/windows.sh} windows.sh --replace-fail @efibootmgr@ /test/efibootmgr
          bash ${../../checks/windows.sh} "$PWD/windows.sh"
          touch "$out"
        '';
    checks.cli-config =
      pkgs.runCommand "cli-config-check"
        {
          nativeBuildInputs = with pkgs; [
            fd
            fish
            git
            starship
            tmux
            yazi
            zoxide
          ];
        }
        ''
          export HOME="$TMPDIR/home" XDG_CONFIG_HOME="$TMPDIR/config" XDG_DATA_HOME="$TMPDIR/data"
          export XDG_STATE_HOME="$TMPDIR/state" XDG_CACHE_HOME="$TMPDIR/cache"
          export HERDR_NO_AUTO=1 TERM=xterm-256color
          mkdir -p "$HOME" "$XDG_CONFIG_HOME/fish/conf.d" "$XDG_CONFIG_HOME/yazi/flavors"
          ln -s ${conf "fish/config.fish"} "$XDG_CONFIG_HOME/fish/config.fish"
          ln -s ${conf "fish/conf.d/plugin-fzf-fish.fish"} "$XDG_CONFIG_HOME/fish/conf.d/plugin-fzf-fish.fish"
          ln -s ${conf "yazi/yazi.toml"} "$XDG_CONFIG_HOME/yazi/yazi.toml"
          ln -s ${conf "yazi/theme.toml"} "$XDG_CONFIG_HOME/yazi/theme.toml"
          ln -s ${conf "yazi/flavors/rose-pine-dawn.yazi"} "$XDG_CONFIG_HOME/yazi/flavors/rose-pine-dawn.yazi"
          cd "$HOME"
          mkdir -p .git demo
          touch .dotfile .git/never-listed
          fish -n "$XDG_CONFIG_HOME/fish/config.fish"
          fish -i -c '
            functions -q __zoxide_z; and functions -q fish_prompt; or exit 1
            bind ctrl-alt-f | string match -q "*fzf*"; or exit 1
            for key in ctrl-v ctrl-r
              bind $key 2>/dev/null | string match -q "*fzf*"; and exit 1
            end
            test "$PERSONAL" = "$HOME/personal"; or exit 1
            test (eval $FZF_DEFAULT_COMMAND) = .dotfile; or exit 1
            cd demo; and test "$PWD" = "$HOME/demo"
          '
          STARSHIP_CONFIG=${home.home.file.${home.programs.starship.configPath}.source} \
            starship module character --status=0 | grep -F '󰘧'
          git -c include.path=${conf "git/config"} config --get push.default | grep -Fx simple
          git -c include.path=${conf "git/config"} ls-remote --get-url https://github.com/example/repo.git | grep -Fx git@github.com:example/repo.git
          git -c include.path=${conf "git/config"} config --get pager.diff | grep -F delta
          git -c include.path=${conf "git/config"} config --get filter.lfs.required | grep -Fx true
          yazi --debug > yazi.log 2>&1
          cat yazi.log
          if grep -Eqi 'failed to (parse|load)|invalid (config|type)' yazi.log; then exit 1; fi

          env -u TMUX tmux -S "$TMPDIR/tmux.sock" -f ${conf "tmux/tmux.conf"} new-session -d 'sleep 60'
          tm() { env -u TMUX tmux -S "$TMPDIR/tmux.sock" "$@"; }
          trap 'tm kill-server' EXIT
          tm show-options -gv status-position | grep -Fx top
          tm show-options -gv history-limit | grep -Fx 25000
          tm show-options -gv prefix | grep -Fx C-b
          tm show-options -gv base-index | grep -Fx 1
          tm show-options -gwv pane-base-index | grep -Fx 1
          tm show-options -gwv mode-keys | grep -Fx vi
          tm show-options -gv @rose_pine_variant | grep -Fx dawn
          tm list-keys -T prefix > tmux-keys
          grep -E 'prefix H +select-pane -L$' tmux-keys
          grep -E 'prefix \| +split-window -h -c "#\{pane_current_path\}"$' tmux-keys
          touch "$out"
        '';
  };
}
