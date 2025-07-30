{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.ollama-ipex;
in
{
  options.services.ollama-ipex = {
    enable = mkEnableOption "Ollama with Intel IPEX acceleration";
    
    package = mkOption {
      type = types.package;
      default = pkgs.ollama-ipex;
      description = "The Ollama package with IPEX support to use";
    };
    
    host = mkOption {
      type = types.str;
      default = "127.0.0.1";
      description = "The host address to bind to";
    };
    
    port = mkOption {
      type = types.port;
      default = 11434;
      description = "The port to listen on";
    };
    
    models = mkOption {
      type = types.str;
      default = "/var/lib/ollama/models";
      description = "Directory to store downloaded models";
    };
    
    acceleration = mkOption {
      type = types.enum [ "auto" "cpu" "gpu" ];
      default = "auto";
      description = "Acceleration backend to use";
    };
    
    user = mkOption {
      type = types.str;
      default = "ollama";
      description = "User to run Ollama service as";
    };
    
    group = mkOption {
      type = types.str;
      default = "ollama";
      description = "Group to run Ollama service as";
    };
  };
  
  config = mkIf cfg.enable {
    # Ensure IPEX support is enabled
    services.ipex.enable = mkDefault true;
    
    # Create user and group
    users.users.${cfg.user} = {
      isSystemUser = true;
      group = cfg.group;
      home = "/var/lib/ollama";
      createHome = true;
      extraGroups = [ "render" "video" ];
    };
    
    users.groups.${cfg.group} = {};
    
    # Systemd service
    systemd.services.ollama-ipex = {
      description = "Ollama with Intel IPEX acceleration";
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];
      
      environment = {
        OLLAMA_HOST = "${cfg.host}:${toString cfg.port}";
        OLLAMA_MODELS = cfg.models;
        # Intel GPU environment variables
        ZES_ENABLE_SYSMAN = "1";
        ONEAPI_DEVICE_SELECTOR = mkIf (cfg.acceleration != "cpu") "opencl:*";
      };
      
      serviceConfig = {
        Type = "simple";
        User = cfg.user;
        Group = cfg.group;
        ExecStart = "${cfg.package}/bin/ollama serve";
        Restart = "on-failure";
        RestartSec = "5s";
        
        # Security hardening
        NoNewPrivileges = true;
        PrivateTmp = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        ReadWritePaths = [ cfg.models "/var/lib/ollama" ];
        
        # Resource limits
        MemoryMax = "8G";
        CPUQuota = "400%";
      };
    };
    
    # Firewall configuration
    networking.firewall.allowedTCPPorts = mkIf (cfg.host != "127.0.0.1") [ cfg.port ];
    
    # State directory
    systemd.tmpfiles.rules = [
      "d ${cfg.models} 0755 ${cfg.user} ${cfg.group} -"
      "d /var/lib/ollama 0755 ${cfg.user} ${cfg.group} -"
    ];
  };
}
