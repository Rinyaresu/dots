{ config, ... }:
{
  flake.modules.nixos.ssh-agent = { config, pkgs, ... }: {
    key = "${__curPos.file}#nixos.ssh-agent";
    programs.ssh = {
      startAgent = true;
      enableAskPassword = true;
      askPassword = "${pkgs.openssh-askpass}/libexec/gtk-ssh-askpass";
      extraConfig = ''
        AddKeysToAgent yes
      '';
    };
    environment.variables.SSH_ASKPASS_REQUIRE = "prefer";
    assertions = [
      {
        assertion = config.programs.ssh.startAgent && !config.services.gnome.gcr-ssh-agent.enable;
        message = "The native OpenSSH agent must be enabled without GCR competing for SSH_AUTH_SOCK.";
      }
      {
        assertion = config.programs.ssh.agentTimeout == null;
        message = "The session SSH agent keeps identities until explicit removal or agent shutdown.";
      }
    ];
  };

  flake.modules.nixos.base = {
    imports = [ config.flake.modules.nixos.ssh-agent ];
  };
}
