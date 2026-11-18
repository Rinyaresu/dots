{
  flake.modules.nixos.docker = { pkgs, ... }: {
    key = "${__curPos.file}#nixos.docker";
    virtualisation.docker = {
      enable = true;
      enableOnBoot = true;
      daemon.settings = {
        ip = "127.0.0.1";
        default-network-opts.bridge."com.docker.network.bridge.host_binding_ipv4" = "127.0.0.1";
      };
    };
    environment.systemPackages = [ pkgs.docker-compose ];
  };
}
