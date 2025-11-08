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
  
  # Use kernel 6.18-rc4 from overlay
  boot.kernelPackages = pkgs.linuxPackages_6_18_rc4;
  boot.kernelModules = [ "xe" "vfio" "vfio_pci" "vfio_iommu_type1" ];
  boot.supportedFilesystems = [ "nfs" ]; 

  # Setup parameters for Arc iGPU VF - i915 driver (better VF support)
  boot.kernelParams = [
    "intel_iommu=on"
    "iommu=pt"
    "boot.shell_on_fail"
  ];
  
  # Native xe SR-IOV support - no extra module packages needed
  # boot.extraModulePackages = [ pkgs.i915-sriov ];  # Removed - using native xe driver
  boot.initrd.availableKernelModules = [ "xe" ];
}
