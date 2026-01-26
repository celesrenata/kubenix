{ pkgs, ... }:
{
  # Use the systemd-boot EFI boot loader.
  boot.initrd.systemd.enable = true;
  boot.loader = {
    systemd-boot.enable = true;
    efi = {
      canTouchEfiVariables = false;
    };
    grub = {
      efiSupport = true;
      efiInstallAsRemovable = true;
      device = "nodev";
    };
  };
  # KMS Module loading
  boot.initrd.kernelModules = [ "vmd" "md_mod" "raid0" "xe" ];
  
  # Use kernel 6.18 from overlay
  boot.kernelPackages = pkgs.linuxPackages_6_18;
  boot.kernelModules = [ "xe" ];
  boot.supportedFilesystems = [ "nfs" ]; 

  # Setup parameters for Arc GPU with xe driver
  boot.kernelParams = [
    "intel_iommu=on"
    "iommu=pt"
    "xe.enable_guc=3"
    "xe.force_probe=7d55"
    "boot.shell_on_fail"
  ];
  
  boot.initrd.availableKernelModules = [ "xe" ];
}
