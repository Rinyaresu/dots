{ config, ... }:
{
  flake.modules.homeManager.obsidian = { pkgs, ... }: {
    key = "${__curPos.file}#homeManager.obsidian";
    home.packages = [ pkgs.obsidian ];
  };
  flake.modules.homeManager.anki = { pkgs, ... }: {
    key = "${__curPos.file}#homeManager.anki";
    home.packages = [ pkgs.anki ];
  };
  flake.modules.homeManager.dbeaver = { pkgs, ... }: {
    key = "${__curPos.file}#homeManager.dbeaver";
    home.packages = [ pkgs.dbeaver-bin ];
  };
  flake.modules.homeManager.code = { lib, pkgs, ... }: {
    key = "${__curPos.file}#homeManager.code";
    home.packages = [
      (pkgs.vscode.overrideAttrs (old: {
        postPatch =
          assert lib.hasInfix "resources/app/node_modules/@vscode/ripgrep/bin/rg" old.postPatch;
          lib.replaceStrings
            [ "resources/app/node_modules/@vscode/ripgrep/bin/rg" ]
            [ "resources/app/node_modules.asar.unpacked/@vscode/ripgrep-universal/bin/linux-x64/rg" ]
            old.postPatch;
      }))
    ];
  };
  flake.modules.homeManager.bitwarden = { pkgs, ... }: {
    key = "${__curPos.file}#homeManager.bitwarden";
    home.packages = [ pkgs.bitwarden-desktop ];
  };

  flake.modules.homeManager.desktop-personal = {
    imports = [
      config.flake.modules.homeManager.obsidian
      config.flake.modules.homeManager.anki
      config.flake.modules.homeManager.dbeaver
      config.flake.modules.homeManager.code
      config.flake.modules.homeManager.bitwarden
    ];
  };
}
