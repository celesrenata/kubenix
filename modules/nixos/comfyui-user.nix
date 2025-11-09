{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.comfyui-user;
in {
  options.services.comfyui-user = {
    enable = mkEnableOption "ComfyUI user service with Intel XPU support";
    
    user = mkOption {
      type = types.str;
      default = "celes";
      description = "User to run ComfyUI service as";
    };
    
    port = mkOption {
      type = types.port;
      default = 8188;
      description = "Port for ComfyUI web interface";
    };
    
    dataDir = mkOption {
      type = types.str;
      default = "/home/celes/.local/share/comfyui";
      description = "Directory for ComfyUI data and models";
    };
  };

  config = mkIf cfg.enable {
    # Create data directories
    systemd.tmpfiles.rules = [
      "d ${cfg.dataDir} 0755 ${cfg.user} users -"
      "d ${cfg.dataDir}/models 0755 ${cfg.user} users -"
      "d ${cfg.dataDir}/input 0755 ${cfg.user} users -"
      "d ${cfg.dataDir}/output 0755 ${cfg.user} users -"
      "d ${cfg.dataDir}/temp 0755 ${cfg.user} users -"
      "d ${cfg.dataDir}/user 0755 ${cfg.user} users -"
    ];

    # ComfyUI user service
    systemd.user.services.comfyui = {
      description = "ComfyUI with Intel XPU support";
      wantedBy = [ "default.target" ];
      after = [ "graphical-session.target" ];
      
      environment = {
        # Intel GPU environment
        ZES_ENABLE_SYSMAN = "1";
        ONEAPI_DEVICE_SELECTOR = "opencl:*";
        SYCL_CACHE_PERSISTENT = "1";
        SYCL_PI_LEVEL_ZERO_USE_IMMEDIATE_COMMANDLISTS = "1";
        
        # Intel library paths
        MKLROOT = "${pkgs.intel-mkl}";
        LD_LIBRARY_PATH = "${pkgs.intel-mkl}/lib:${pkgs.intel-compute-runtime}/lib:/run/opengl-driver/lib";
      };
      
      serviceConfig = {
        Type = "exec";
        ExecStartPre = [
          # Install optional dependencies with pip
          "${pkgs.python3}/bin/pip install --user pydantic pydantic-settings kornia spandrel alembic comfyui-workflow-templates comfyui-embedded-docs"
        ];
        ExecStart = "${pkgs.comfyui-xpu}/bin/comfyui-xpu --listen 0.0.0.0 --port ${toString cfg.port} --cpu --oneapi-device-selector opencl:* --user-directory ${cfg.dataDir}/user --output-directory ${cfg.dataDir}/output --input-directory ${cfg.dataDir}/input --temp-directory ${cfg.dataDir}/temp";
        Restart = "always";
        RestartSec = "3";
        WorkingDirectory = cfg.dataDir;
      };
    };

    # Open firewall for ComfyUI
    networking.firewall.allowedTCPPorts = [ cfg.port ];
  };
}
