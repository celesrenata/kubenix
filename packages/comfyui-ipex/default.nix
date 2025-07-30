{ lib
, buildPythonApplication
, fetchFromGitHub
, intel-xpu
, makeWrapper
, writeText
, writeShellScript
# Python dependencies
, torch
, torchvision
, torchaudio
, torchsde
, einops
, transformers
, tokenizers
, sentencepiece
, safetensors
, aiohttp
, pyyaml
, pillow
, scipy
, tqdm
, psutil
, kornia
, spandrel
, soundfile
, gitpython
}:

let
  # ComfyUI version - using latest stable
  version = "2024-07-30";
  
  # Intel XPU device support patch
  xpu-device-patch = writeText "01-intel-xpu-device-support.patch" ''
    diff --git a/model_management.py b/model_management.py
    index 1234567..abcdefg 100644
    --- a/model_management.py
    +++ b/model_management.py
    @@ -15,6 +15,11 @@ try:
         import intel_extension_for_pytorch as ipex
         IPEX_AVAILABLE = True
     except ImportError:
         IPEX_AVAILABLE = False
    +    
    +# Intel XPU support
    +def is_intel_xpu_available():
    +    return IPEX_AVAILABLE and hasattr(torch, 'xpu') and torch.xpu.is_available()
    +
    +INTEL_XPU_AVAILABLE = is_intel_xpu_available()
     
     def get_torch_device():
         if args.cpu:
    @@ -25,6 +30,9 @@ def get_torch_device():
             return torch.device("mps")
         elif torch.cuda.is_available():
             return torch.device("cuda")
    +    elif INTEL_XPU_AVAILABLE:
    +        return torch.device("xpu")
         else:
             return torch.device("cpu")
  '';
  
  # Memory management optimization patch
  memory-optimization-patch = writeText "02-intel-memory-optimization.patch" ''
    diff --git a/model_management.py b/model_management.py
    index abcdefg..1234567 100644
    --- a/model_management.py
    +++ b/model_management.py
    @@ -45,6 +45,15 @@ def get_free_memory(dev=None, torch_free_too=False):
             mem_free_torch = model_free_memory
             mem_free_total = mem_free_torch
             return mem_free_total, mem_free_torch
    +    elif dev.type == "xpu":
    +        # Intel XPU memory management
    +        try:
    +            mem_free_total = torch.xpu.get_device_properties(dev.index).total_memory
    +            mem_free_torch = mem_free_total - torch.xpu.memory_allocated(dev.index)
    +            return mem_free_total, mem_free_torch
    +        except:
    +            # Fallback to conservative estimate
    +            return 4 * 1024**3, 2 * 1024**3  # 4GB total, 2GB free
         else:
             # CPU memory estimation
             mem_free_total = psutil.virtual_memory().available
  '';
  
  # Model loading optimization patch
  model-loading-patch = writeText "03-intel-model-loading.patch" ''
    diff --git a/model_management.py b/model_management.py
    index 1234567..abcdefg 100644
    --- a/model_management.py
    +++ b/model_management.py
    @@ -120,6 +120,18 @@ def load_model_gpu(model):
             model = model.to(model_management.get_torch_device())
             if IPEX_AVAILABLE and model_management.get_torch_device().type == "xpu":
                 model = ipex.optimize(model, dtype=torch.float16, level="O1")
    +        
    +        # Intel XPU specific optimizations
    +        if hasattr(model, 'to') and model_management.get_torch_device().type == "xpu":
    +            # Enable Intel GPU optimizations
    +            try:
    +                import intel_extension_for_pytorch as ipex
    +                model = ipex.optimize(model, dtype=torch.float16)
    +                # Enable JIT compilation for better performance
    +                if hasattr(torch.jit, 'optimize_for_inference'):
    +                    model = torch.jit.optimize_for_inference(model)
    +            except Exception as e:
    +                print(f"Intel XPU optimization warning: {e}")
             
             return model
         except Exception as e:
  '';

in buildPythonApplication rec {
  pname = "comfyui-ipex";
  inherit version;
  format = "other";

  src = fetchFromGitHub {
    owner = "comfyanonymous";
    repo = "ComfyUI";
    rev = "v${version}";
    hash = "sha256-0000000000000000000000000000000000000000000="; # Placeholder - needs actual hash
  };

  nativeBuildInputs = [
    makeWrapper
  ];

  propagatedBuildInputs = [
    # Intel IPEX stack
    intel-xpu.python.pkgs.ipex
    intel-xpu.python.pkgs.torch
    intel-xpu.python.pkgs.torchvision
    intel-xpu.python.pkgs.torchaudio
    
    # ComfyUI dependencies
    torchsde
    einops
    transformers
    tokenizers
    sentencepiece
    safetensors
    aiohttp
    pyyaml
    pillow
    scipy
    tqdm
    psutil
    kornia
    spandrel
    soundfile
    gitpython
  ];

  patches = [
    xpu-device-patch
    memory-optimization-patch
    model-loading-patch
  ];

  # Don't run setup.py - ComfyUI doesn't have one
  dontBuild = true;
  dontConfigure = true;

  installPhase = ''
    runHook preInstall
    
    # Create installation directory
    mkdir -p $out/lib/comfyui
    
    # Copy ComfyUI source
    cp -r . $out/lib/comfyui/
    
    # Create wrapper script
    mkdir -p $out/bin
    cat > $out/bin/comfyui-ipex << 'EOF'
    #!/usr/bin/env bash
    
    # Intel XPU environment variables
    export ZES_ENABLE_SYSMAN=1
    export ONEAPI_DEVICE_SELECTOR="opencl:*"
    
    # ComfyUI configuration
    export COMFYUI_PATH="$out/lib/comfyui"
    
    # Change to ComfyUI directory and run
    cd "$COMFYUI_PATH"
    exec ${intel-xpu.python}/bin/python main.py "$@"
    EOF
    
    chmod +x $out/bin/comfyui-ipex
    
    # Create desktop entry
    mkdir -p $out/share/applications
    cat > $out/share/applications/comfyui-ipex.desktop << 'EOF'
    [Desktop Entry]
    Name=ComfyUI (Intel IPEX)
    Comment=A powerful and modular stable diffusion GUI with Intel XPU acceleration
    Exec=comfyui-ipex --listen 0.0.0.0
    Icon=applications-graphics
    Terminal=false
    Type=Application
    Categories=Graphics;Photography;
    EOF
    
    runHook postInstall
  '';

  # Wrap the Python environment
  postFixup = ''
    wrapProgram $out/bin/comfyui-ipex \
      --prefix PYTHONPATH : "$out/lib/comfyui:$PYTHONPATH" \
      --set ZES_ENABLE_SYSMAN "1" \
      --set ONEAPI_DEVICE_SELECTOR "opencl:*"
  '';

  meta = with lib; {
    description = "A powerful and modular stable diffusion GUI with Intel IPEX acceleration";
    homepage = "https://github.com/comfyanonymous/ComfyUI";
    license = licenses.gpl3Plus;
    maintainers = [ ];
    platforms = platforms.linux;
    mainProgram = "comfyui-ipex";
  };
}
