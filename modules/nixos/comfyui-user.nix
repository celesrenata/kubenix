{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.comfyui-user;
  # SYCL runtime library path (from intel-dpcpp or compatible LLVM with SYCL support)
  syclLibPath = "/nix/store/fbyzx0y4nzisia1l73a5ka3bva4cd6h3-intel-dpcpp-2025.1-lib/lib";
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
      "d ${cfg.dataDir}/models/checkpoints 0755 ${cfg.user} users -"
      "d ${cfg.dataDir}/models/vae 0755 ${cfg.user} users -"
      "d ${cfg.dataDir}/models/loras 0755 ${cfg.user} users -"
      "d ${cfg.dataDir}/models/upscale_models 0755 ${cfg.user} users -"
      "d ${cfg.dataDir}/models/embeddings 0755 ${cfg.user} users -"
      "d ${cfg.dataDir}/models/controlnet 0755 ${cfg.user} users -"
      "d ${cfg.dataDir}/input 0755 ${cfg.user} users -"
      "d ${cfg.dataDir}/output 0755 ${cfg.user} users -"
      "d ${cfg.dataDir}/temp 0755 ${cfg.user} users -"
      "d ${cfg.dataDir}/user 0755 ${cfg.user} users -"
      "d ${cfg.dataDir}/user/db 0755 ${cfg.user} users -"
      "d ${cfg.dataDir}/sycl_cache 0755 ${cfg.user} users -"
    ];

    # ComfyUI user service
    systemd.user.services.comfyui = {
      description = "ComfyUI with Intel XPU support";
      wantedBy = [ "default.target" ];
      after = [ "graphical-session.target" ];
      
      environment = {
        # Intel GPU environment (updated based on Intel Arc setup)
        ZES_ENABLE_SYSMAN = "1";
        ONEAPI_DEVICE_SELECTOR = "level_zero:gpu";
        SYCL_CACHE_PERSISTENT = "1";
        SYCL_CACHE_DIR = "${cfg.dataDir}/sycl_cache";
        SYCL_PI_LEVEL_ZERO_USE_IMMEDIATE_COMMANDLISTS = "1";
        SYCL_DEVICE_FILTER = "level_zero:gpu";
        
        # Intel library paths (site-packages first to use wheel versions of libsycl, libccl, etc.)
        MKLROOT = "${pkgs.intel-mkl}";
        LD_LIBRARY_PATH = "/home/celes/.local/lib/python3.12/site-packages:/home/celes/.local/lib/python3.12/site-packages/torch/lib:/home/celes/.local/lib/python3.12/site-packages/torchaudio/lib:${pkgs.level-zero}/lib:${pkgs.intel-mkl}/lib:${pkgs.intel-compute-runtime}/lib:/run/opengl-driver/lib:${pkgs.gcc-unwrapped.lib}/lib:${pkgs.stdenv.cc.cc.lib}/lib";
        
        # Add bash, system python3, uv, git, and .local/bin to PATH (for alembic)
        PATH = lib.mkForce "/home/celes/.local/bin:${pkgs.bash}/bin:${pkgs.coreutils}/bin:/etc/profiles/per-user/celes/bin:${pkgs.uv}/bin:${pkgs.git}/bin:${pkgs.stdenv.shell}";
        
        # UV environment for user installation
        UV_PYTHON = "/etc/profiles/per-user/celes/bin/python3";
        PYTHONPATH = "/home/celes/.local/lib/python3.12/site-packages:${pkgs.comfyui-xpu}/lib/comfyui";
        
        # ComfyUI path for wrapper script
        COMFYUI_PATH = "${pkgs.comfyui-xpu}/lib/comfyui";
        
        # Disable CUDA at service level
        CUDA_VISIBLE_DEVICES = "";
        
        # Disable PyTorch's scaled_dot_product_attention which has oneDNN primitive issues on Arc
        PYTORCH_ENABLE_MPS_FALLBACK = "1";
        TORCH_ALLOW_TF32_CUBLAS_OVERRIDE = "0";
        
        # ComfyUI custom nodes directory
        COMFYUI_CUSTOM_NODES = "${cfg.dataDir}/custom_nodes";
      };
      
      serviceConfig = {
        Type = "exec";
        TimeoutStartSec = "600";  # 10 minutes for pip install
        ExecStartPre = [
          # Create user site-packages directory
          "${pkgs.coreutils}/bin/mkdir -p /home/celes/.local/lib/python3.12/site-packages"
          # Create missing templates directory
          "${pkgs.coreutils}/bin/mkdir -p /home/celes/.local/lib/python3.12/site-packages/comfyui_workflow_templates/templates"
          # Create custom_nodes directory and symlink to ComfyUI path
          "${pkgs.coreutils}/bin/mkdir -p ${cfg.dataDir}/custom_nodes"
          "${pkgs.bash}/bin/bash -c 'if [ ! -d ${cfg.dataDir}/custom_nodes/ComfyUI-Manager ]; then ${pkgs.git}/bin/git clone https://github.com/ltdrdata/ComfyUI-Manager.git ${cfg.dataDir}/custom_nodes/ComfyUI-Manager; fi'"
          "${pkgs.bash}/bin/bash -c 'ln -sfn ${cfg.dataDir}/custom_nodes ${pkgs.comfyui-xpu}/lib/comfyui/custom_nodes || true'"
          # Create extra model paths config
          "${pkgs.bash}/bin/bash -c \"echo -e 'comfyui:\\n  base_path: ${cfg.dataDir}/\\n  checkpoints: models/checkpoints/\\n  vae: models/vae/\\n  loras: models/loras/\\n  upscale_models: models/upscale_models/\\n  embeddings: models/embeddings/\\n  controlnet: models/controlnet/' > ${cfg.dataDir}/extra_model_paths.yaml\""
          # Create pip.conf to override torch packages with XPU index
          "${pkgs.bash}/bin/bash -c \"mkdir -p /home/celes/.config/pip && echo -e '[global]\\nindex-url = https://pypi.org/simple\\nextra-index-url = https://download.pytorch.org/whl/nightly/xpu' > /home/celes/.config/pip/pip.conf\""
          # Install PyTorch XPU with pip (nightly build - only version with native XPU support)
          "${pkgs.python312Packages.pip}/bin/pip install --pre --user --break-system-packages --index-url https://download.pytorch.org/whl/nightly/xpu torch torchvision torchaudio"
          # Extract .so files from Intel wheels (pip doesn't install them correctly)
          "${pkgs.bash}/bin/bash ${pkgs.replaceVars ./../../packages/extract-intel-libs.sh { wget = "${pkgs.wget}/bin/wget"; unzip = "${pkgs.unzip}/bin/unzip"; }}"
          # Install other dependencies with uv
          "${pkgs.uv}/bin/uv pip install --target /home/celes/.local/lib/python3.12/site-packages --break-system-packages pydantic pydantic-settings kornia spandrel alembic comfyui-workflow-templates comfyui-embedded-docs pyyaml tqdm psutil transformers scipy av aiohttp comfyui-frontend-package safetensors tokenizers torchsde"
        ];
        ExecStart = "/etc/profiles/per-user/celes/bin/python3 ${pkgs.comfyui-xpu}/lib/comfyui/main.py --listen 0.0.0.0 --port ${toString cfg.port} --preview-method auto --lowvram --disable-smart-memory --use-pytorch-cross-attention --oneapi-device-selector level_zero:gpu --base-directory ${cfg.dataDir} --user-directory ${cfg.dataDir}/user --output-directory ${cfg.dataDir}/output --input-directory ${cfg.dataDir}/input --temp-directory ${cfg.dataDir}/temp --extra-model-paths-config ${cfg.dataDir}/extra_model_paths.yaml";
        Restart = "always";
        RestartSec = "3";
        WorkingDirectory = cfg.dataDir;
      };
    };

    # Open firewall for ComfyUI
    networking.firewall.allowedTCPPorts = [ cfg.port ];
  };
}
