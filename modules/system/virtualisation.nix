{
  flake.modules.nixos.virtualisation = { pkgs, ... }: {
    key = "${__curPos.file}#nixos.virtualisation";
    virtualisation.libvirtd = {
      enable = true;
      onBoot = "ignore";
      qemu.runAsRoot = false;
    };
    programs.virt-manager.enable = true;
    environment.systemPackages = [ pkgs.qemu_kvm ];
  };
}
