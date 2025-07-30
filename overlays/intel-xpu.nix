{ mordrag-nixos }:

final: prev: {
  # Intel XPU ecosystem packages from MordragT's flake
  intel-xpu = {
    # Core IPEX components
    python = mordrag-nixos.packages.${final.system}.intel-python;
    ipex = mordrag-nixos.packages.${final.system}.intel-python.pkgs.ipex;
    
    # Intel base libraries
    mkl = mordrag-nixos.packages.${final.system}.intel-mkl;
    tbb = mordrag-nixos.packages.${final.system}.intel-tbb;
    dpcpp = mordrag-nixos.packages.${final.system}.intel-dpcpp;
    
    # AI/ML applications with IPEX support
    ollama = mordrag-nixos.packages.${final.system}.ollama-sycl;
    invokeai = mordrag-nixos.packages.${final.system}.invokeai;
    
    # Development tools
    # TODO: Add more development tools as needed
  };
  
  # Convenient aliases for direct access
  ollama-ipex = final.intel-xpu.ollama;
  python-ipex = final.intel-xpu.python;
  
  # Override default packages to use IPEX versions when available
  # ollama = final.intel-xpu.ollama;  # Uncomment to make IPEX default
}
