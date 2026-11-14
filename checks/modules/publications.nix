{ config, ... }:
let
  nixos = config.flake.modules.nixos;
  home = config.flake.modules.homeManager;
  implementation = {
    key = "${__curPos.file}#nixos.local-implementation";
    marks = [ "implementation" ];
  };
in
{
  imports = [
    {
      flake.modules.nixos.intra = {
        key = "${__curPos.file}#nixos.intra-first";
        marks = [ "intra-a" ];
      };
    }
    {
      flake.modules.nixos.intra = {
        key = "${__curPos.file}#nixos.intra-second";
        marks = [ "intra-b" ];
      };
    }
  ];
  flake.modules.nixos = {
    address-a = implementation;
    address-b = implementation;
    alpha = {
      key = "${__curPos.file}#nixos.alpha";
      marks = [ "system-alpha" ];
    };
    beta = { ... }: {
      key = "${__curPos.file}#nixos.beta";
      marks = [ "system-beta" ];
    };
    multi = {
      key = "${__curPos.file}#nixos.multi";
      marks = [ "system-a" ];
    };
    left = {
      key = "${__curPos.file}#nixos.left";
      imports = [ nixos.multi ];
    };
    right = {
      key = "${__curPos.file}#nixos.right";
      imports = [ nixos.multi ];
    };
  };
  flake.modules.homeManager = {
    alpha = { ... }: {
      key = "${__curPos.file}#homeManager.alpha";
      marks = [ "home-alpha" ];
    };
    beta = {
      key = "${__curPos.file}#homeManager.beta";
      marks = [ "home-beta" ];
    };
    multi = {
      key = "${__curPos.file}#homeManager.multi";
      marks = [ "home-a" ];
    };
    left = {
      key = "${__curPos.file}#homeManager.left";
      imports = [ home.multi ];
    };
    right = {
      key = "${__curPos.file}#homeManager.right";
      imports = [ home.multi ];
    };
  };
}
