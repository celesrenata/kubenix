{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.comfyui-ipex;
in
{
  options.services.comfyui-ipex = {
    enable = mkEnableOption "ComfyUI with Intel IPEX acceleration";
    
    package = mkOption {
      type = types.package;
      default = pkgs.comfyui-ipex;
      description = "The ComfyUI package with IPEX support to use";
    };
    
    host = mkOption {
      type = types.str;
      default = "127.0.0.1";
      description = "The host address to bind to";
    };
    
    port = mkOption {
      type = types.port;
      default = 8188;
      description = "The port to listen on";
    };
    
    models = {
      path = mkOption {
        type = types.str;
        default = "/var/lib/comfyui/models";
        description = "Directory to store ComfyUI models";
      };
      
      autoDownload = mkOption {
        type = types.bool;
        default = false;
        description = "Automatically download common models on first start";
      };
      
      cache = {
        enable = mkOption {
          type = types.bool;
          default = true;
          description = "Enable model caching for faster loading";
        };
        
        size = mkOption {
          type = types.str;
          default = "10GB";
          description = "Maximum cache size";
        };
      };
    };
    
    nodes = {
      enable = mkOption {
        type = types.listOf types.str;
        default = [ ];
        description = "List of custom nodes to enable";
        example = [ "controlnet-aux" "upscaling" ];
      };
      
      custom = mkOption {
        type = types.listOf types.package;
        default = [ ];
        description = "Custom node packages to install";
      };
    };
    
    acceleration = mkOption {
      type = types.enum [ "auto" "cpu" "xpu" ];
      default = "auto";
      description = "Acceleration backend to use";
    };
    
    optimization = {
      level = mkOption {
        type = types.enum [ "O0" "O1" "O2" "O3" ];
        default = "O1";
        description = "Intel IPEX optimization level";
      };
      
      precision = mkOption {
        type = types.enum [ "fp32" "fp16" "bf16" "int8" ];
        default = "fp16";
        description = "Model precision for optimization";
      };
      
      jitCompile = mkOption {
        type = types.bool;
        default = true;
        description = "Enable JIT compilation for better performance";
      };
    };
    
    server = {
      cors = mkOption {
        type = types.bool;
        default = false;
        description = "Enable CORS for web interface";
      };
      
      maxUploadSize = mkOption {
        type = types.str;
        default = "100M";
        description = "Maximum upload size for images";
      };
    };
    
    user = mkOption {
      type = types.str;
      default = "comfyui";
      description = "User to run ComfyUI service as";
    };
    
    group = mkOption {
      type = types.str;
      default = "comfyui";
      description = "Group to run ComfyUI service as";
    };
  };
  
  config = mkIf cfg.enable {
    # Ensure IPEX support is enabled
    services.ipex.enable = mkDefault true;
    
    # Create user and group
    users.users.${cfg.user} = {
      isSystemUser = true;
      group = cfg.group;
      home = "/var/lib/comfyui";
      createHome = true;
      extraGroups = [ "render" "video" ];
    };
    
    users.groups.${cfg.group} = {};
    
    # Install ComfyUI package
    environment.systemPackages = [ cfg.package ];
    
    # Systemd service
    systemd.services.comfyui-ipex = {
      description = "ComfyUI with Intel IPEX acceleration";
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" "ipex.service" ];
      wants = [ "ipex.service" ];
      
      environment = {
        # Intel GPU environment variables
        ZES_ENABLE_SYSMAN = "1";
        ONEAPI_DEVICE_SELECTOR = mkIf (cfg.acceleration != "cpu") "opencl:*";
        
        # ComfyUI configuration
        COMFYUI_HOST = cfg.host;
        COMFYUI_PORT = toString cfg.port;
        COMFYUI_MODELS_PATH = cfg.models.path;
        
        # Intel IPEX optimization
        IPEX_OPTIMIZATION_LEVEL = cfg.optimization.level;
        IPEX_PRECISION = cfg.optimization.precision;
        IPEX_JIT_COMPILE = if cfg.optimization.jitCompile then "1" else "0";
      };
      
      serviceConfig = {
        Type = "simple";
        User = cfg.user;
        Group = cfg.group;
        WorkingDirectory = "/var/lib/comfyui";
        
        ExecStartPre = mkIf cfg.models.autoDownload (pkgs.writeShellScript "comfyui-setup" ''
          # Create model directories
          mkdir -p ${cfg.models.path}/{checkpoints,vae,loras,controlnet,upscale_models}
          
          # Download basic models if they don't exist
          if [ ! -f "${cfg.models.path}/checkpoints/sd_xl_base_1.0.safetensors" ]; then
            echo "Downloading SDXL base model..."
            ${pkgs.wget}/bin/wget -O "${cfg.models.path}/checkpoints/sd_xl_base_1.0.safetensors" \
              "https://huggingface.co/stabilityai/stable-diffusion-xl-base-1.0/resolve/main/sd_xl_base_1.0.safetensors" || true
          fi
        '');
        
        ExecStart = ''
          ${cfg.package}/bin/comfyui-ipex \
            --listen ${cfg.host} \
            --port ${toString cfg.port} \
            ${optionalString cfg.server.cors "--enable-cors-header"} \
            ${optionalString (cfg.acceleration == "cpu") "--cpu"} \
            ${optionalString (cfg.acceleration == "xpu") "--force-fp16"}
        '';
        
        Restart = "on-failure";
        RestartSec = "10s";
        
        # Security hardening
        NoNewPrivileges = true;
        PrivateTmp = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        ReadWritePaths = [ 
          cfg.models.path 
          "/var/lib/comfyui"
          "/tmp"  # For temporary model processing
        ];
        
        # Resource limits
        MemoryMax = "16G";  # Larger for image processing
        CPUQuota = "800%";  # Allow more CPU usage
        
        # Network access for model downloads
        PrivateNetwork = false;
      };
    };
    
    # Firewall configuration
    networking.firewall.allowedTCPPorts = mkIf (cfg.host != "127.0.0.1") [ cfg.port ];
    
    # State directories and permissions
    systemd.tmpfiles.rules = [
      "d ${cfg.models.path} 0755 ${cfg.user} ${cfg.group} -"
      "d ${cfg.models.path}/checkpoints 0755 ${cfg.user} ${cfg.group} -"
      "d ${cfg.models.path}/vae 0755 ${cfg.user} ${cfg.group} -"
      "d ${cfg.models.path}/loras 0755 ${cfg.user} ${cfg.group} -"
      "d ${cfg.models.path}/controlnet 0755 ${cfg.user} ${cfg.group} -"
      "d ${cfg.models.path}/upscale_models 0755 ${cfg.user} ${cfg.group} -"
      "d ${cfg.models.path}/embeddings 0755 ${cfg.user} ${cfg.group} -"
      "d /var/lib/comfyui 0755 ${cfg.user} ${cfg.group} -"
      "d /var/lib/comfyui/output 0755 ${cfg.user} ${cfg.group} -"
      "d /var/lib/comfyui/input 0755 ${cfg.user} ${cfg.group} -"
      "d /var/lib/comfyui/temp 0755 ${cfg.user} ${cfg.group} -"
    ] ++ optionals cfg.models.cache.enable [
      "d /var/cache/comfyui 0755 ${cfg.user} ${cfg.group} -"
    ];
    
    # Logrotate configuration
    services.logrotate.settings.comfyui-ipex = {
      files = "/var/log/comfyui-ipex.log";
      frequency = "weekly";
      rotate = 4;
      compress = true;
      delaycompress = true;
      missingok = true;
      notifempty = true;
      create = "644 ${cfg.user} ${cfg.group}";
    };
  };
}
