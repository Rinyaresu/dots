{
  flake.modules.nixos.ssh-agent = {
    key = "${__curPos.file}#nixos.ssh-agent";
    programs.ssh.startAgent = true;
  };
}
