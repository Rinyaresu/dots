{
  flake.modules.nixos.base = {
    services.openssh.enable = false;
    programs.ssh.startAgent = true;
  };
}
