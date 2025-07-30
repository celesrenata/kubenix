{ lib
, buildPythonPackage
, fetchFromGitHub
, intel-xpu
, opencv4
, pillow
, numpy
, torch
, torchvision
, spandrel
}:

buildPythonPackage rec {
  pname = "comfyui-upscaling-ipex";
  version = "2024-07-30";
  format = "setuptools";

  src = fetchFromGitHub {
    owner = "city96";
    repo = "ComfyUI_ExtraModels";
    rev = "main";
    hash = "sha256-0000000000000000000000000000000000000000000="; # Placeholder - needs actual hash
  };

  propagatedBuildInputs = [
    # Intel IPEX optimized packages
    intel-xpu.python.pkgs.torch
    intel-xpu.python.pkgs.torchvision
    intel-xpu.python.pkgs.spandrel
    
    # Standard dependencies
    opencv4
    pillow
    numpy
  ];

  # Patch for Intel XPU support
  postPatch = ''
    # Add Intel XPU device support
    find . -name "*.py" -exec sed -i 's/torch\.device("cuda")/torch.device("xpu" if torch.xpu.is_available() else "cuda")/g' {} \;
    find . -name "*.py" -exec sed -i 's/\.cuda()/\.to(torch.device("xpu" if torch.xpu.is_available() else "cuda"))/g' {} \;
    
    # Add IPEX optimization for upscaling models
    cat >> __init__.py << 'EOF'

# Intel IPEX optimization for upscaling
try:
    import intel_extension_for_pytorch as ipex
    
    def optimize_upscaling_model(model):
        """Optimize upscaling model with Intel IPEX"""
        if torch.xpu.is_available():
            model = model.to('xpu')
            model = ipex.optimize(model, dtype=torch.float16, level="O1")
        return model
        
    IPEX_AVAILABLE = True
except ImportError:
    def optimize_upscaling_model(model):
        return model
    IPEX_AVAILABLE = False
EOF
  '';

  # Don't run tests - they require models
  doCheck = false;

  meta = with lib; {
    description = "ComfyUI upscaling models with Intel IPEX support";
    homepage = "https://github.com/city96/ComfyUI_ExtraModels";
    license = licenses.gpl3Plus;
    maintainers = [ ];
    platforms = platforms.linux;
  };
}
