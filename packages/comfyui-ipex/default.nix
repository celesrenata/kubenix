{ lib
, python312Packages  # Use Python 3.12 to match MordragT's IPEX packages
, fetchFromGitHub
, intel-xpu ? null
, makeWrapper
, writeText
, writeShellScript
}:

let
  # ComfyUI version - ACTUAL latest from GitHub with built-in Intel XPU support!
  version = "0.3.47";

in python312Packages.buildPythonApplication rec {
  pname = "comfyui-ipex";
  inherit version;
  format = "other";

  src = fetchFromGitHub {
    owner = "comfyanonymous";
    repo = "ComfyUI";
    rev = "v${version}";
    hash = "sha256-Kcw91IC1yPzn2NeBLTUyJ2AdFkTdE9v8j6iabK/f7JY=";
  };

  nativeBuildInputs = [
    makeWrapper
  ];

  propagatedBuildInputs = with python312Packages; [
    # Core ComfyUI dependencies
    pillow
    pyyaml
    psutil
    numpy
    safetensors
    aiohttp
    
    # Additional ML dependencies
    scipy
    tqdm
    
    # Missing ComfyUI dependencies
    einops
    transformers
    tokenizers
    
    # Try to include PyTorch (may need Intel IPEX version)
    # torch torchvision torchaudio
  ] ++ lib.optionals (intel-xpu != null) [
    # Intel IPEX stack when available - this enables the built-in Intel XPU support!
    intel-xpu.python.pkgs.ipex
    intel-xpu.python.pkgs.torch
    intel-xpu.python.pkgs.torchvision
  ];

  # No patches needed - ComfyUI v0.3.47 has Intel XPU support built-in!
  patches = [ ];

  # Don't run setup.py - ComfyUI doesn't have one
  dontBuild = true;
  dontConfigure = true;

  installPhase = ''
    runHook preInstall
    
    # Create installation directory
    mkdir -p $out/lib/comfyui
    
    # Copy ComfyUI source
    cp -r . $out/lib/comfyui/
    
    # Create main wrapper script with Intel XPU support
    mkdir -p $out/bin
    cat > $out/bin/comfyui-ipex << EOF
#!/usr/bin/env bash

# Intel XPU environment variables
export ZES_ENABLE_SYSMAN=1
export ONEAPI_DEVICE_SELECTOR="opencl:*"

# ComfyUI configuration
export COMFYUI_PATH="$out/lib/comfyui"

# Usage information
if [[ "\$1" == "--help-gpu" ]]; then
    echo "ComfyUI v0.3.47 with built-in Intel XPU + NVIDIA CUDA support"
    echo ""
    echo "🎉 GREAT NEWS: ComfyUI v0.3.47 has native Intel XPU support!"
    echo ""
    echo "GPU Selection Options:"
    echo "  (default)                    - Auto-detect: Intel XPU > CUDA > CPU"
    echo "  --cpu                        - Force CPU only"
    echo "  --oneapi-device-selector S   - Select specific Intel device"
    echo "  --disable-ipex-optimize      - Disable Intel IPEX optimizations"
    echo ""
    echo "Intel XPU Specific:"
    echo "  --oneapi-device-selector 'opencl:*'     # All OpenCL devices"
    echo "  --oneapi-device-selector 'level_zero:*' # All Level Zero devices"
    echo "  --oneapi-device-selector 'opencl:0'     # Specific OpenCL device"
    echo ""
    echo "Examples:"
    echo "  comfyui-ipex                                    # Auto-detect best GPU"
    echo "  comfyui-ipex --oneapi-device-selector 'opencl:0' # Force Intel GPU 0"
    echo "  comfyui-cuda                                    # Force NVIDIA CUDA"
    echo "  comfyui-xpu                                     # Intel XPU optimized"
    echo ""
    echo "Environment Variables:"
    echo "  ZES_ENABLE_SYSMAN=1          # Enable Intel GPU system management"
    echo "  ONEAPI_DEVICE_SELECTOR       # Intel device selection"
    echo "  CUDA_VISIBLE_DEVICES         # NVIDIA device selection"
    echo ""
    exit 0
fi

# Change to ComfyUI directory and run
cd "\$COMFYUI_PATH"
exec python3 main.py "\$@"
EOF
    
    chmod +x $out/bin/comfyui-ipex
    
    # Create NVIDIA-specific wrapper (preserves CUDA priority)
    cat > $out/bin/comfyui-cuda << 'EOF'
#!/usr/bin/env bash
# Force NVIDIA CUDA usage by disabling Intel XPU detection
export ONEAPI_DEVICE_SELECTOR=""
cd "$out/lib/comfyui"
exec python3 main.py "$@"
EOF
    
    chmod +x $out/bin/comfyui-cuda
    
    # Create Intel XPU-optimized wrapper
    cat > $out/bin/comfyui-xpu << 'EOF'
#!/usr/bin/env bash
# Optimized Intel XPU usage
export ZES_ENABLE_SYSMAN=1
export ONEAPI_DEVICE_SELECTOR="opencl:*"
cd "$out/lib/comfyui"
exec python3 main.py --oneapi-device-selector "opencl:*" "$@"
EOF
    
    chmod +x $out/bin/comfyui-xpu
    
    # Create Intel XPU Level Zero wrapper (alternative driver)
    cat > $out/bin/comfyui-xpu-l0 << 'EOF'
#!/usr/bin/env bash
# Intel XPU with Level Zero driver
export ZES_ENABLE_SYSMAN=1
export ONEAPI_DEVICE_SELECTOR="level_zero:*"
cd "$out/lib/comfyui"
exec python3 main.py --oneapi-device-selector "level_zero:*" "$@"
EOF
    
    chmod +x $out/bin/comfyui-xpu-l0
    
    # Create desktop entry
    mkdir -p $out/share/applications
    cat > $out/share/applications/comfyui-ipex.desktop << 'EOF'
[Desktop Entry]
Name=ComfyUI (Intel XPU + NVIDIA)
Comment=Stable Diffusion GUI with native Intel XPU + NVIDIA CUDA support
Exec=comfyui-ipex --listen 0.0.0.0
Icon=applications-graphics
Terminal=false
Type=Application
Categories=Graphics;Photography;
EOF
    
    runHook postInstall
  '';

  # Wrap the Python environment with Intel GPU support
  postFixup = ''
    wrapProgram $out/bin/comfyui-ipex \
      --prefix PYTHONPATH : "$out/lib/comfyui:$PYTHONPATH" \
      --set ZES_ENABLE_SYSMAN "1" \
      --set ONEAPI_DEVICE_SELECTOR "opencl:*"
      
    wrapProgram $out/bin/comfyui-cuda \
      --prefix PYTHONPATH : "$out/lib/comfyui:$PYTHONPATH"
      
    wrapProgram $out/bin/comfyui-xpu \
      --prefix PYTHONPATH : "$out/lib/comfyui:$PYTHONPATH" \
      --set ZES_ENABLE_SYSMAN "1" \
      --set ONEAPI_DEVICE_SELECTOR "opencl:*"
      
    wrapProgram $out/bin/comfyui-xpu-l0 \
      --prefix PYTHONPATH : "$out/lib/comfyui:$PYTHONPATH" \
      --set ZES_ENABLE_SYSMAN "1" \
      --set ONEAPI_DEVICE_SELECTOR "level_zero:*"
  '';

  meta = with lib; {
    description = "ComfyUI v0.3.47 with native Intel XPU + NVIDIA CUDA support";
    longDescription = ''
      ComfyUI with built-in Intel XPU support (no patches needed!).
      
      🎉 ComfyUI v0.3.47 includes native Intel XPU support with:
      - Automatic Intel XPU device detection
      - Intel IPEX optimizations built-in
      - OneAPI device selector support
      - Full NVIDIA CUDA compatibility preserved
      
      Features:
      - Four binaries: comfyui-ipex, comfyui-cuda, comfyui-xpu, comfyui-xpu-l0
      - Automatic GPU detection: Intel XPU > CUDA > CPU
      - Intel XPU optimizations with --oneapi-device-selector
      - Level Zero and OpenCL driver support
      - Full compatibility with existing CUDA workflows
    '';
    homepage = "https://github.com/comfyanonymous/ComfyUI";
    license = licenses.gpl3Plus;
    maintainers = [ ];
    platforms = platforms.linux;
    mainProgram = "comfyui-ipex";
  };
}
