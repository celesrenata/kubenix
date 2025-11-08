{ config, lib, pkgs, ... }:
{
  # Add Intel-specific packages
  environment.systemPackages = with pkgs; [
    nvtopPackages.intel
  ];

  hardware.graphics = {
    enable = true;
    extraPackages = with pkgs; [
      intel-compute-runtime.drivers
      intel-media-driver    # VA-API driver for Intel Arc
      vpl-gpu-rt           # for newer GPUs on NixOS >24.05 or unstable
    ];
  };

  hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
  hardware.enableRedistributableFirmware = true;
  hardware.enableAllFirmware = true;

  # Custom iGPU Firmware for Arc iGPU
  hardware.firmware = [
    pkgs.linux-firmwareOverride
  ];

  # Use modesetting driver for SR-IOV guest - works with i915 kernel module
  services.xserver.videoDrivers = [ "modesetting" ];

  # Explicit device section for Intel Arc GPU SR-IOV
  services.xserver.deviceSection = ''
    BusID "PCI:8:0:0"
    Option "AccelMethod" "glamor"
    Option "DRI" "3"
  '';

  # Ensure render nodes are created
  services.udev.extraRules = ''
    SUBSYSTEM=="drm", KERNEL=="renderD*", GROUP="render", MODE="0664"
    SUBSYSTEM=="drm", KERNEL=="card*", GROUP="video", MODE="0664"
  '';

  # Add render group
  users.groups.render = {};

  # Intel SR-IOV support is handled by the i915-sriov NixOS module
}
