{
  flake.modules.homeManager.desktop-personal = { lib, pkgs, ... }: {
    key = "${__curPos.file}#homeManager.desktop-personal";
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
}
