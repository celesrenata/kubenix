{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.ipex;
in
{
  options.services.ipex = {
    enable = mkEnableOption "Intel IPEX (Intel Extension for PyTorch) support";
    
    autoDetectHardware = mkOption {
      type = types.bool;
      default = true;
      description = "Automatically detect and configure Intel GPU hardware";
    };
    
    devices = mkOption {
      type = types.listOf (types.enum [ "gpu" "cpu" ]);
      default = [ "gpu" "cpu" ];
      description = "Intel devices to enable for IPEX acceleration";
    };
    
    optimization = mkOption {
      type = types.enum [ "performance" "balanced" "power" ];
      default = "balanced";
      description = "Optimization profile for IPEX workloads";
    };
  };
  
  config = mkIf cfg.enable {
    # Enable Intel GPU support
    hardware.graphics = mkIf (elem "gpu" cfg.devices) {
      enable = true;
      extraPackages = with pkgs; [
        intel-media-driver
        intel-compute-runtime
        level-zero
      ];
    };
    
    # System packages for IPEX development
    environment.systemPackages = with pkgs; [
      intel-xpu.python
      # Add more IPEX tools as needed
    ];
    
    # Environment variables for Intel GPU
    environment.variables = mkIf (elem "gpu" cfg.devices) {
      # Level Zero configuration
      ZES_ENABLE_SYSMAN = "1";
      # OpenCL configuration  
      ONEAPI_DEVICE_SELECTOR = "opencl:*";
    };
    
    # User groups for GPU access
    users.groups.render = {};
    users.groups.video = {};
    
    # Assertions for hardware requirements
    assertions = [
      {
        assertion = cfg.autoDetectHardware -> config.hardware.graphics.enable;
        message = "Intel GPU hardware detection requires hardware.graphics.enable = true";
      }
    ];
  };
}
