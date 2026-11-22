{ config, ... }:
{
  flake.modules.nixos.fish.key = "${__curPos.file}#nixos.fish";
  flake.modules.nixos.fish.programs.fish.enable = true;
  flake.modules.homeManager.fish = { pkgs, ... }: {
    key = "${__curPos.file}#homeManager.fish";
    home.sessionVariables.PERSONAL = "$HOME/personal";
    home.sessionVariables.FZF_DEFAULT_COMMAND = "fd --type f --hidden --exclude .git";

    programs = {
      fish = {
        enable = true;
        plugins = [
          {
            name = "fzf-fish";
            src = pkgs.fishPlugins.fzf-fish.src;
          }
        ];
        interactiveShellInit = ''
          set -g fzf_fd_opts --hidden --exclude .git
          if functions -q fzf_configure_bindings
            fzf_configure_bindings --history= --variables=
          end
        '';
        shellAliases = {
          d = "lazydocker";
          g = "lazygit";
          gl = ''git log --graph --pretty="%Cred%h%Creset -%C(auto)%d%Creset %s %Cgreen(%ar) %C(bold blue)<%an>%Creset" --all'';
          l = "git log -p --follow --";
          grep = "grep --color=auto";
          tree = "eza --tree --all --ignore-glob=.git";
          vim = "nvim";
          r = "rails";
          migrate = "bundle exec rails db:migrate";
          create = "bundle exec rails db:create";
          drop = "bundle exec rails db:drop";
          rollback = "bundle exec rails db:rollback";
          seed = "bundle exec rails db:seed";
          reset = "bundle exec rails db:reset";
          setup = "bundle exec rails db:setup";
          ba = "bundle add";
          bu = "bundle update";
          bi = "bundle install";
          be = "bundle exec";
          rs = "bundle exec rspec";
          rt = "bundle exec rails test:all";
          guard = "bundle exec guard";
          routes = "bundle exec rails routes | fzf";
        };
      };
      zoxide = {
        enable = true;
        enableFishIntegration = true;
        options = [
          "--cmd"
          "cd"
        ];
      };
      starship = {
        enable = true;
        enableFishIntegration = true;
        settings = builtins.fromTOML (builtins.readFile ./starship.toml);
      };
    };
  };

  flake.modules.homeManager.base = {
    imports = [ config.flake.modules.homeManager.fish ];
  };
}
