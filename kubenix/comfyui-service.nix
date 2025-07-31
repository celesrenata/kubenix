{ config, pkgs, ... }:

{
  # ComfyUI service with Intel IPEX acceleration
  systemd.services.comfyui = {
    description = "ComfyUI with Intel IPEX-LLM acceleration";
    wantedBy = [ "multi-user.target" ];
    after = [ "network.target" ];

    environment = {
      # Intel OneAPI environment variables
      ZES_ENABLE_SYSMAN = "1";
      ONEAPI_DEVICE_SELECTOR = "opencl:*";
      SYCL_CACHE_PERSISTENT = "1";
      SYCL_PI_LEVEL_ZERO_USE_IMMEDIATE_COMMANDLISTS = "1";
      
      # Intel GPU driver environment
      ZES_DEBUG = "1";
      ZE_DEBUG = "1";
      ZE_ENABLE_VALIDATION_LAYER = "1";
      SYCL_PI_TRACE = "2";
      
      # ComfyUI configuration
      COMFYUI_HOST = "0.0.0.0";
      COMFYUI_PORT = "8188";
      
      # Debug and logging
      COMFYUI_DEBUG = "1";
    };

    serviceConfig = {
      Type = "exec";
      User = "comfyui";
      Group = "comfyui";
      ExecStart = pkgs.writeShellScript "comfyui-with-ipex-env" ''
        # For now, we'll use a simple ComfyUI installation
        # TODO: Replace with our IPEX-LLM integrated version
        
        echo "🚀 Starting ComfyUI with Intel IPEX acceleration..."
        echo "📍 ComfyUI will be available at: http://0.0.0.0:8188"
        echo "🎯 Intel GPU Environment:"
        echo "   ZES_ENABLE_SYSMAN=$ZES_ENABLE_SYSMAN"
        echo "   ONEAPI_DEVICE_SELECTOR=$ONEAPI_DEVICE_SELECTOR"
        
        # Install ComfyUI if not present
        if [ ! -d "/var/lib/comfyui/ComfyUI" ]; then
          echo "📦 Installing ComfyUI..."
          cd /var/lib/comfyui
          ${pkgs.git}/bin/git clone https://github.com/comfyanonymous/ComfyUI.git
          cd ComfyUI
          ${pkgs.python3}/bin/python -m pip install --user -r requirements.txt
        fi
        
        # Start ComfyUI
        cd /var/lib/comfyui/ComfyUI
        exec ${pkgs.python3}/bin/python main.py \
          --listen 0.0.0.0 \
          --port 8188 \
          --oneapi-device-selector "opencl:*"
      '';
      Restart = "always";
      RestartSec = "3";
      WorkingDirectory = "/var/lib/comfyui";
      StateDirectory = "comfyui";
      
      # Security settings
      NoNewPrivileges = false;  # Need privileges for pip install
      PrivateTmp = true;
      ReadWritePaths = [ "/var/lib/comfyui" ];
    };
  };

  # Create comfyui user and group
  users.users.comfyui = {
    isSystemUser = true;
    group = "comfyui";
    home = "/var/lib/comfyui";
    createHome = true;
    extraGroups = [ "render" ]; # For Intel GPU access
  };

  users.groups.comfyui = {};

  # Create required directories with proper permissions
  systemd.tmpfiles.rules = [
    "d /var/lib/comfyui 0755 comfyui comfyui -"
    "d /var/lib/comfyui/models 0755 comfyui comfyui -"
    "d /var/lib/comfyui/output 0755 comfyui comfyui -"
    "d /var/lib/comfyui/input 0755 comfyui comfyui -"
    "d /var/lib/comfyui/temp 0755 comfyui comfyui -"
  ];

  # Open firewall for ComfyUI
  networking.firewall.allowedTCPPorts = [ 8188 ];

  # Install required packages for ComfyUI
  environment.systemPackages = with pkgs; [
    python3
    python3Packages.pip
    python3Packages.torch
    python3Packages.torchvision
    python3Packages.torchaudio
    python3Packages.pillow
    python3Packages.numpy
    python3Packages.safetensors
    python3Packages.aiohttp
    python3Packages.pyyaml
    python3Packages.psutil
    git
  ];

  # Intel GPU driver packages
  hardware.graphics = {
    enable = true;
    extraPackages = with pkgs; [
      intel-compute-runtime
      level-zero
      intel-gmmlib
    ];
  };
}
