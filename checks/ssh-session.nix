{ nixos, pkgs }:
let
  askpass = pkgs.writeShellScript "fixture-ssh-askpass" ''
    echo prompt >> "$HOME/prompts"
    test ! -e "$HOME/cancel" || exit 1
    echo fixture-passphrase
  '';
in
pkgs.testers.runNixOSTest {
  name = "ssh-session";
  nodes.machine = { lib, ... }: {
    imports = [ nixos.ssh-agent ];
    users.users.alice = {
      isNormalUser = true;
      uid = 1000;
      initialPassword = "fixture";
    };
    services.openssh = {
      enable = true;
      settings = {
        PasswordAuthentication = false;
        KbdInteractiveAuthentication = false;
      };
    };
    programs.ssh.askPassword = lib.mkForce "${askpass}";
    environment.systemPackages = [ pkgs.openssh ];
  };
  testScript = ''
    machine.start()
    machine.wait_for_unit("sshd.service")
    machine.succeed("install -d -m 0700 -o alice -g users /home/alice/.ssh")
    machine.succeed("su - alice -c 'ssh-keygen -q -t ed25519 -N fixture-passphrase -f ~/.ssh/id_ed25519'")
    machine.succeed("cp /home/alice/.ssh/id_ed25519.pub /home/alice/.ssh/authorized_keys")
    machine.succeed("awk '{ print \"localhost \" $1 \" \" $2 }' /etc/ssh/ssh_host_ed25519_key.pub > /home/alice/.ssh/known_hosts")
    machine.succeed("chown -R alice:users /home/alice/.ssh; chmod 0600 /home/alice/.ssh/authorized_keys /home/alice/.ssh/known_hosts")
    machine.succeed("systemctl start user@1000.service")
    machine.wait_until_succeeds("test -S /run/user/1000/ssh-agent")

    def alice(command):
        return "su - alice -c 'export SSH_AUTH_SOCK=/run/user/1000/ssh-agent SSH_ASKPASS=${askpass} SSH_ASKPASS_REQUIRE=force; " + command + "'"

    client = "ssh -o StrictHostKeyChecking=yes -o ForwardAgent=no -o ControlMaster=no -o ControlPath=none -o ConnectTimeout=5 alice@localhost printf authenticated"
    machine.succeed(alice("ssh-add -l; test $? = 1"))
    machine.succeed("touch /home/alice/cancel")
    machine.fail(alice(client))
    machine.succeed(alice("ssh-add -l; test $? = 1"))
    machine.succeed("rm /home/alice/cancel")
    assert machine.succeed(alice(client)).strip() == "authenticated"
    machine.succeed(alice("ssh-add -l"))
    assert machine.succeed(alice(client)).strip() == "authenticated"
    assert machine.succeed("wc -l < /home/alice/prompts").strip() == "2"
    machine.succeed(alice("ssh-add -D"))
    machine.succeed(alice("ssh-add -l; test $? = 1"))
    assert machine.succeed(alice(client)).strip() == "authenticated"
    assert machine.succeed("wc -l < /home/alice/prompts").strip() == "3"
  '';
}
