{
  flake.modules.homeManager.desktop-personal =
    { lib, pkgs, ... }:
    let
      script =
        name:
        pkgs.writeScriptBin name ''
          #!${lib.getExe pkgs.python3}
          ${builtins.readFile (./_scripts + "/${name}.py")}
        '';
    in
    {
      key = "${__curPos.file}#homeManager.work-tools";
      home.packages = [ (script "clean") ];
    };
}
