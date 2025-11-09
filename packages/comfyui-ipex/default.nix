{ lib
, python312Packages
, fetchFromGitHub
, pytorch  # Use PyTorch with Intel optimizations
, makeWrapper
, writeText
, writeShellScript
, intel-mkl
, intel-tbb
, intel-dpcpp
, comfyui-frontend-package
}:

let
  # ComfyUI version - Latest with Intel XPU support
  version = "0.3.67";

in python312Packages.buildPythonApplication rec {
  pname = "comfyui-ipex";
  inherit version;
  format = "other";

  src = fetchFromGitHub {
    owner = "comfyanonymous";
    repo = "ComfyUI";
    rev = "v${version}";
    hash = "sha256-/zfs6HqhpgsblG4MgDPN9ZGz5abwHNkHrGq3uX/f6pQ=";
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
    
    # Additional dependencies for k_diffusion
    torchsde
    
    # Video processing support (new in v0.3.67)
    av
    
    # ComfyUI frontend package (required for v0.3.67+)
    comfyui-frontend-package
    
    # PyTorch with Intel optimizations (use Python 3.12 compatible version)
    torch
    torchvision
    torchaudio
  ];

  # Patch ComfyUI to handle missing CUDA gracefully
  patches = [ 
    ./fix-cuda-detection.patch
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
    
    # Create main wrapper script with Intel IPEX-LLM support
    mkdir -p $out/bin
    cat > $out/bin/comfyui-ipex << EOF
#!/usr/bin/env bash

# Intel OneAPI environment variables
export ZES_ENABLE_SYSMAN=1
export ONEAPI_DEVICE_SELECTOR="opencl:*"
export SYCL_CACHE_PERSISTENT=1
export SYCL_PI_LEVEL_ZERO_USE_IMMEDIATE_COMMANDLISTS=1

# Intel library paths
export MKLROOT="${intel-mkl.out}"
export TBBROOT="${intel-tbb.out}"
export DNNLROOT="${intel-dpcpp.llvm}"

# ComfyUI configuration
export COMFYUI_PATH="$out/lib/comfyui"

# Usage information
if [[ "\$1" == "--help-gpu" ]]; then
    echo "ComfyUI v0.3.47 with Intel-optimized PyTorch"
    echo ""
    echo "🚀 Using PyTorch with Intel MKL optimizations!"
    echo ""
    echo "GPU Selection Options:"
    echo "  (default)                    - Auto-detect: Intel XPU > CUDA > CPU"
    echo "  --cpu                        - Force CPU only"
    echo "  --oneapi-device-selector S   - Select specific Intel device"
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
# Optimized Intel XPU usage with our IPEX-LLM
export ZES_ENABLE_SYSMAN=1
export ONEAPI_DEVICE_SELECTOR="opencl:*"
export SYCL_CACHE_PERSISTENT=1
export SYCL_PI_LEVEL_ZERO_USE_IMMEDIATE_COMMANDLISTS=1
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
export SYCL_CACHE_PERSISTENT=1
export SYCL_PI_LEVEL_ZERO_USE_IMMEDIATE_COMMANDLISTS=1
cd "$out/lib/comfyui"
exec python3 main.py --oneapi-device-selector "level_zero:*" "$@"
EOF
    
    chmod +x $out/bin/comfyui-xpu-l0
    
    # Create desktop entry
    mkdir -p $out/share/applications
    cat > $out/share/applications/comfyui-ipex.desktop << 'EOF'
[Desktop Entry]
Name=ComfyUI (Intel Optimized)
Comment=Stable Diffusion GUI with Intel-optimized PyTorch
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
    # Source Intel OneAPI environment for all wrappers
    for wrapper in $out/bin/comfyui-*; do
      wrapProgram "$wrapper" \
        --prefix PYTHONPATH : "$out/lib/comfyui:${pytorch}/${python312Packages.python.sitePackages}:$PYTHONPATH" \
        --prefix PATH : "${intel-mkl.out}/bin:${intel-tbb.out}/bin:${intel-dpcpp.llvm}/bin" \
        --set MKLROOT "${intel-mkl.out}" \
        --set TBBROOT "${intel-tbb.out}" \
        --set DNNLROOT "${intel-dpcpp.llvm}" \
        --prefix LD_LIBRARY_PATH : "${lib.makeLibraryPath [ intel-mkl.out intel-tbb.out intel-dpcpp.llvm ]}"
    done
    
    # Set Intel-specific environment for XPU wrappers
    wrapProgram $out/bin/comfyui-ipex \
      --set ZES_ENABLE_SYSMAN "1" \
      --set ONEAPI_DEVICE_SELECTOR "opencl:*" \
      --set SYCL_CACHE_PERSISTENT "1" \
      --set SYCL_PI_LEVEL_ZERO_USE_IMMEDIATE_COMMANDLISTS "1"
      
    wrapProgram $out/bin/comfyui-xpu \
      --set ZES_ENABLE_SYSMAN "1" \
      --set ONEAPI_DEVICE_SELECTOR "opencl:*" \
      --set SYCL_CACHE_PERSISTENT "1" \
      --set SYCL_PI_LEVEL_ZERO_USE_IMMEDIATE_COMMANDLISTS "1"
      
    wrapProgram $out/bin/comfyui-xpu-l0 \
      --set ZES_ENABLE_SYSMAN "1" \
      --set ONEAPI_DEVICE_SELECTOR "level_zero:*" \
      --set SYCL_CACHE_PERSISTENT "1" \
      --set SYCL_PI_LEVEL_ZERO_USE_IMMEDIATE_COMMANDLISTS "1"
  '';

  meta = with lib; {
    description = "ComfyUI v0.3.47 with Intel-optimized PyTorch";
    longDescription = ''
      ComfyUI with Intel-optimized PyTorch using MKL and Intel GPU support.
      
      🚀 Features:
      - ComfyUI v0.3.47 with Intel GPU support
      - PyTorch with Intel MKL optimizations
      - Proper Intel OneAPI environment integration
      - Multiple GPU backends: Intel XPU, NVIDIA CUDA, CPU
      - Four optimized binaries for different use cases
      
      Binaries:
      - comfyui-ipex: Auto-detect best GPU with Intel optimizations
      - comfyui-cuda: Force NVIDIA CUDA usage
      - comfyui-xpu: Intel XPU optimized with OpenCL
      - comfyui-xpu-l0: Intel XPU with Level Zero driver
      
      Built the Nix way: Pure, reproducible, from source! ✨
    '';
    homepage = "https://github.com/comfyanonymous/ComfyUI";
    license = licenses.gpl3Plus;
    maintainers = [ ];
    platforms = platforms.linux;
    mainProgram = "comfyui-ipex";
  };
}
