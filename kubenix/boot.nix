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
  boot.initrd.kernelModules = [ "vmd" "md_mod" "raid0" "i915" ];
  
  # Update to modern kernel 6.15
  boot.kernelPackages = pkgs.linuxPackages_6_15;
  boot.kernelModules = [ "i915" "vfio" "vfio_pci" "vfio_iommu_type1" ];
  boot.supportedFilesystems = [ "nfs" ];
  boot.blacklistedKernelModules = [ "xe" ]; 

  # Setup SR-IOV Required Parameters for Arc iGPU - same as gremlin-1
  boot.kernelParams = [
    "intel_iommu=on"
    "iommu=pt"
    "i915.enable_guc=3"
    "i915.force_probe=7d55"
    "boot.shell_on_fail"
  ];
  
  # Modern SR-IOV Module for guest system
  boot.extraModulePackages = [ pkgs.i915-sriov ];
  boot.initrd.availableKernelModules = [ "i915" ];
}
