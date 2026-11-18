{ config, ... }:
{
  flake.modules.nixos.rinyaresu = { pkgs, ... }: {
    key = "${__curPos.file}#nixos.rinyaresu";
    imports = [ config.flake.modules.nixos.fish ];
    users.users.rinyaresu = {
      isNormalUser = true;
      uid = 1000;
      extraGroups = [ "wheel" ];
      shell = pkgs.fish;
    };
  };

  flake.modules.homeManager.rinyaresu = {
    key = "${__curPos.file}#homeManager.rinyaresu";
    imports = [ config.flake.modules.homeManager.git ];
    programs.git.settings.user = {
      name = "Kaique Linhares";
      email = "79602114+Rinyaresu@users.noreply.github.com";
    };
  };

  flake.modules.nixos.base = {
    imports = [ config.flake.modules.nixos.rinyaresu ];
  };
  flake.modules.homeManager.base = {
    imports = [ config.flake.modules.homeManager.rinyaresu ];
  };
}
