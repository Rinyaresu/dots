{
  flake.modules.nixos.virtualisation = { pkgs, ... }: {
    virtualisation.libvirtd = {
      enable = true;
      onBoot = "ignore";
      qemu.runAsRoot = false;
    };
    programs.virt-manager.enable = true;
    environment.systemPackages = [ pkgs.qemu_kvm ];
  };
}
