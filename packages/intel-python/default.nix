{ lib, callPackage, python3, python310, python311, python312 }:

let
  # Import build support functions
  buildSupport = callPackage ./build-support.nix { };
  
  # Version configuration
  versions = {
    torch = "2.7.1";
    ipex = "2.7.10";
    sycl = "6.1.0";
  };
  
  # Create Intel Python environment for a specific Python version
  mkIntelPython = pythonVersion: let
    pythonPkg = {
      "310" = python310;
      "311" = python311; 
      "312" = python312;
    }.${pythonVersion} or (throw "Unsupported Python version: ${pythonVersion}");
    
    pythonCpTag = "cp${pythonVersion}";
    
    # Validate compatibility
    _ = buildSupport.validateCompatibility {
      torch_version = "${versions.torch}+xpu";
      ipex_version = "${versions.ipex}+xpu";
      python_version = pythonCpTag;
    };
    
  in pythonPkg.override {
    packageOverrides = self: super: {
      # PyTorch with Intel XPU support
      torch = callPackage ./torch {
        inherit buildSupport pythonCpTag;
        python = pythonPkg;
        torch_version = versions.torch;
      };
      
      # Intel Extension for PyTorch
      intel-extension-for-pytorch = callPackage ./ipex {
        inherit buildSupport pythonCpTag;
        python = pythonPkg;
        ipex_version = versions.ipex;
        torch = self.torch;
      };
      
      # Supporting packages
      triton-xpu = callPackage ./triton-xpu {
        inherit buildSupport pythonCpTag;
        python = pythonPkg;
      };
      
      oneccl-bind-pt = callPackage ./oneccl-bind-pt {
        inherit buildSupport pythonCpTag;
        python = pythonPkg;
      };
    };
  };

in {
  # Multi-version Python environments
  python310 = mkIntelPython "310";
  python311 = mkIntelPython "311";
  python312 = mkIntelPython "312";
  
  # Default to Python 3.12
  python3 = mkIntelPython "312";
  
  # Individual packages for direct access
  inherit buildSupport versions;
  
  # Utility functions
  inherit mkIntelPython;
}
