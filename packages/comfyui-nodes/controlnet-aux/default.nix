{ lib
, buildPythonPackage
, fetchFromGitHub
, intel-xpu
, opencv4
, pillow
, numpy
, scipy
, scikit-image
, transformers
, diffusers
, controlnet-aux  # From intel-python scope
}:

buildPythonPackage rec {
  pname = "comfyui-controlnet-aux-ipex";
  version = "2024-07-30";
  format = "setuptools";

  src = fetchFromGitHub {
    owner = "Fannovel16";
    repo = "comfyui_controlnet_aux";
    rev = "main";
    hash = "sha256-0000000000000000000000000000000000000000000="; # Placeholder - needs actual hash
  };

  propagatedBuildInputs = [
    # Intel IPEX optimized packages
    intel-xpu.python.pkgs.controlnet-aux
    
    # Standard dependencies
    opencv4
    pillow
    numpy
    scipy
    scikit-image
    transformers
    diffusers
  ];

  # Patch for Intel XPU support
  postPatch = ''
    # Add Intel XPU device support to preprocessors
    find . -name "*.py" -exec sed -i 's/device="cuda"/device="xpu" if torch.xpu.is_available() else "cuda"/g' {} \;
    find . -name "*.py" -exec sed -i 's/\.cuda()/\.to(torch.device("xpu" if torch.xpu.is_available() else "cuda"))/g' {} \;
    
    # Add IPEX optimization imports
    sed -i '1i import torch\ntry:\n    import intel_extension_for_pytorch as ipex\n    IPEX_AVAILABLE = True\nexcept ImportError:\n    IPEX_AVAILABLE = False\n' node_wrappers.py || true
  '';

  # Don't run tests - they require models
  doCheck = false;

  pythonImportsCheck = [ "controlnet_aux" ];

  meta = with lib; {
    description = "ComfyUI ControlNet auxiliary preprocessors with Intel IPEX support";
    homepage = "https://github.com/Fannovel16/comfyui_controlnet_aux";
    license = licenses.asl20;
    maintainers = [ ];
    platforms = platforms.linux;
  };
}
