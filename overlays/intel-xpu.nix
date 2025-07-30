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
    
    # ComfyUI with IPEX support (our implementation)
    comfyui = final.comfyui-ipex;
    
    # Development tools
    # TODO: Add more development tools as needed
  };
  
  # Convenient aliases for direct access
  ollama-ipex = final.intel-xpu.ollama;
  python-ipex = final.intel-xpu.python;
  comfyui-ipex = final.callPackage ./packages/comfyui-ipex {};
  
  # ComfyUI custom nodes
  comfyui-nodes-ipex = {
    controlnet-aux = final.callPackage ./packages/comfyui-nodes/controlnet-aux {};
    upscaling = final.callPackage ./packages/comfyui-nodes/upscaling {};
  };
  
  # Override default packages to use IPEX versions when available
  # ollama = final.intel-xpu.ollama;  # Uncomment to make IPEX default
  # comfyui = final.intel-xpu.comfyui;  # Uncomment to make IPEX default
}
