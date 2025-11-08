{ pkgs, ... }:
{
  # Virtualization
  virtualisation.libvirtd = {
    enable = true;
    qemu = {
      package = pkgs.qemu_kvm;
      runAsRoot = true;
      swtpm.enable = true;
      # ovmf configuration removed - now available by default
    };
  };
  programs.virt-manager.enable = true;
  virtualisation.docker.enable = true;
  virtualisation.docker.storageDriver = "btrfs";
}
