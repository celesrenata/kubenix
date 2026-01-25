{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.comfyui-user;
  
  comfyui-wrapper = pkgs.writeShellScript "comfyui-wrapper" ''
    export VENV_DIR=${cfg.dataDir}/venv
    export LD_LIBRARY_PATH=${pkgs.stdenv.cc.cc.lib}/lib:${pkgs.level-zero}/lib:${pkgs.intel-mkl}/lib:${pkgs.intel-compute-runtime}/lib:${pkgs.libGL}/lib:${pkgs.libGLU}/lib:/run/opengl-driver/lib:$LD_LIBRARY_PATH
    
    # Intel GPU environment
    export ZES_ENABLE_SYSMAN=1
    export ONEAPI_DEVICE_SELECTOR=level_zero:gpu
    export SYCL_CACHE_PERSISTENT=1
    export SYCL_CACHE_DIR=${cfg.dataDir}/sycl_cache
    export SYCL_DEVICE_FILTER=level_zero:gpu
    export CUDA_VISIBLE_DEVICES=""
    
    # Create venv if it doesn't exist
    if [ ! -d $VENV_DIR ]; then
      echo 'Creating ComfyUI virtual environment...'
      ${pkgs.python3}/bin/python3 -m venv $VENV_DIR
      $VENV_DIR/bin/pip install --upgrade pip
    fi
    
    # Create writable web directory for custom nodes
    mkdir -p ${cfg.dataDir}/web/extensions
    
    # Install dependencies if not complete
    if [ ! -f ${cfg.dataDir}/.deps_complete ]; then
      echo 'Installing ComfyUI dependencies...'
      $VENV_DIR/bin/pip install --pre --index-url https://download.pytorch.org/whl/nightly/xpu torch torchvision torchaudio
      $VENV_DIR/bin/pip install pydantic kornia spandrel alembic pyyaml tqdm psutil transformers scipy av aiohttp safetensors tokenizers torchsde opencv-python numba comfyui-workflow-templates
      mkdir -p $VENV_DIR/lib/python3.12/site-packages/comfyui_workflow_templates/templates
      touch ${cfg.dataDir}/.deps_complete
    fi
    
    cd ${pkgs.comfyui-xpu}/lib/comfyui
    exec $VENV_DIR/bin/python main.py --base-directory ${cfg.dataDir} --extra-model-paths-config ${cfg.dataDir}/extra_model_paths.yaml "$@"
  '';
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
    systemd.tmpfiles.rules = [
      "d ${cfg.dataDir} 0755 ${cfg.user} users -"
      "d ${cfg.dataDir}/models 0755 ${cfg.user} users -"
      "d ${cfg.dataDir}/models/checkpoints 0755 ${cfg.user} users -"
      "d ${cfg.dataDir}/models/vae 0755 ${cfg.user} users -"
      "d ${cfg.dataDir}/models/loras 0755 ${cfg.user} users -"
      "d ${cfg.dataDir}/custom_nodes 0755 ${cfg.user} users -"
      "d ${cfg.dataDir}/input 0755 ${cfg.user} users -"
      "d ${cfg.dataDir}/output 0755 ${cfg.user} users -"
      "d ${cfg.dataDir}/temp 0755 ${cfg.user} users -"
      "d ${cfg.dataDir}/sycl_cache 0755 ${cfg.user} users -"
    ];

    systemd.user.services.comfyui = {
      description = "ComfyUI with Intel XPU support";
      wantedBy = [ "default.target" ];
      after = [ "graphical-session.target" ];
      
      environment = {
        VIRTUAL_ENV = "${cfg.dataDir}/venv";
        PATH = lib.mkForce "${cfg.dataDir}/venv/bin:${pkgs.git}/bin:/run/current-system/sw/bin";
        COMFYUI_WEB_ROOT = "${cfg.dataDir}/web";
      };
      
      serviceConfig = {
        Type = "exec";
        TimeoutStartSec = "600";
        ExecStartPre = [
          "${pkgs.bash}/bin/bash -c 'if [ ! -d ${cfg.dataDir}/custom_nodes/ComfyUI-Manager ]; then ${pkgs.git}/bin/git clone https://github.com/ltdrdata/ComfyUI-Manager.git ${cfg.dataDir}/custom_nodes/ComfyUI-Manager; fi'"
          "${pkgs.bash}/bin/bash -c \"echo -e 'comfyui:\\n  base_path: ${cfg.dataDir}/\\n  checkpoints: models/checkpoints/\\n  vae: models/vae/\\n  loras: models/loras/' > ${cfg.dataDir}/extra_model_paths.yaml\""
        ];
        ExecStart = "${comfyui-wrapper} --listen 0.0.0.0 --port ${toString cfg.port} --lowvram --use-pytorch-cross-attention";
        Restart = "always";
        RestartSec = "3";
        WorkingDirectory = cfg.dataDir;
      };
    };

    networking.firewall.allowedTCPPorts = [ cfg.port ];
  };
}
