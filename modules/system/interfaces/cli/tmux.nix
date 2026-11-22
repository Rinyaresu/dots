{
  flake.modules.homeManager.gui = { pkgs, ... }: {
    programs.tmux = {
      enable = true;
      prefix = "C-b";
      shell = "${pkgs.fish}/bin/fish";
      baseIndex = 1;
      historyLimit = 25000;
      keyMode = "vi";
      customPaneNavigationAndResize = false;
      plugins = [
        {
          plugin = pkgs.tmuxPlugins.rose-pine;
          extraConfig = "set -g @rose_pine_variant 'dawn'";
        }
      ];
      extraConfig = ''
        set -g status-position top
        bind H select-pane -L
        bind J select-pane -D
        bind K select-pane -U
        bind L select-pane -R
        bind | split-window -h -c "#{pane_current_path}"
        bind - split-window -v -c "#{pane_current_path}"
      '';
    };
  };
}
