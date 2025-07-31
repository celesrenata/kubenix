final: prev: 
let
  # Import MordragT's flake
  mordragFlake = builtins.getFlake "github:MordragT/nixos";
  
  # Get his Intel packages
  mordragIntelPkgs = mordragFlake.packages.${final.system};
  
  # Use current nixpkgs instead of MordragT's to avoid insecure OpenSSL
  # Just override the Go builder issue
  mordragPkgsFixed = final.pkgs.extend (final: prev: {
    # Override buildGo122Module to use current buildGoModule
    buildGo122Module = prev.buildGoModule;
    
    # Add MordragT's Intel packages but use our secure dependencies
    intel-dpcpp = mordragIntelPkgs.intel-dpcpp;
    intel-mkl = mordragIntelPkgs.intel-mkl;
    intel-python = mordragIntelPkgs.intel-python;
    intel-tbb = mordragIntelPkgs.intel-tbb or prev.tbb;
    
    # Use current nixpkgs versions for these to avoid OpenSSL issues
    intel-compute-runtime = prev.intel-compute-runtime;
    level-zero = prev.level-zero;
    intel-media-driver = prev.intel-media-driver;
    intel-gmmlib = prev.intel-gmmlib;
    intel-graphics-compiler = prev.intel-graphics-compiler;
  });
  
  # Build his ollama-sycl with the fixed nixpkgs
  mordragOllama = mordragPkgsFixed.callPackage "${mordragFlake}/pkgs/by-name/ollama-sycl" {};
  
in
{
  # Provide the fixed ollama-sycl
  ollama-sycl = mordragOllama;
  ollama-ipex = mordragOllama;  # Alias
}
