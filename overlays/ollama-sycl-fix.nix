final: prev: 
let
  # Import MordragT's flake
  mordragFlake = builtins.getFlake "github:MordragT/nixos";
  
  # Get his Intel packages
  mordragIntelPkgs = mordragFlake.packages.${final.system};
  
  # Create a modified nixpkgs that provides buildGo122Module as an alias to buildGoModule
  # AND includes ALL of MordragT's Intel packages
  mordragPkgsFixed = import mordragFlake.inputs.nixpkgs {
    inherit (final) system;
    config.allowUnfree = true;
    overlays = [
      # Override buildGo122Module to use current buildGoModule
      (final: prev: {
        buildGo122Module = prev.buildGoModule;
        
        # Add ALL MordragT's Intel packages to avoid dependency hell
        intel-dpcpp = mordragIntelPkgs.intel-dpcpp;
        intel-mkl = mordragIntelPkgs.intel-mkl;
        intel-python = mordragIntelPkgs.intel-python;
        intel-tbb = mordragIntelPkgs.intel-tbb or prev.tbb;  # Fallback to regular tbb
        intel-compute-runtime = mordragIntelPkgs.intel-compute-runtime or prev.intel-compute-runtime;
        level-zero = mordragIntelPkgs.level-zero or prev.level-zero;
        intel-media-driver = mordragIntelPkgs.intel-media-driver or prev.intel-media-driver;
        intel-gmmlib = mordragIntelPkgs.intel-gmmlib or prev.intel-gmmlib;
        intel-graphics-compiler = mordragIntelPkgs.intel-graphics-compiler or prev.intel-graphics-compiler;
      })
    ];
  };
  
  # Build his ollama-sycl with the fixed nixpkgs
  mordragOllama = mordragPkgsFixed.callPackage "${mordragFlake}/pkgs/by-name/ollama-sycl" {};
  
in
{
  # Provide the fixed ollama-sycl
  ollama-sycl = mordragOllama;
  ollama-ipex = mordragOllama;  # Alias
}
