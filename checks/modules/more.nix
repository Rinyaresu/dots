{
  flake.modules.nixos.multi = {
    key = "${__curPos.file}#nixos.multi";
    marks = [ "system-b" ];
  };
  flake.modules.homeManager.multi = {
    key = "${__curPos.file}#homeManager.multi";
    marks = [ "home-b" ];
  };
}
