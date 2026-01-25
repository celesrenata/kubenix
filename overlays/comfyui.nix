final: prev: {
  comfyui-xpu = prev.python3Packages.buildPythonApplication rec {
    pname = "comfyui-xpu";
    version = "0.3.67";
    format = "other";
    
    src = prev.fetchFromGitHub {
      owner = "comfyanonymous";
      repo = "ComfyUI";
      rev = "v0.3.67";
      hash = "sha256-/zfs6HqhpgsblG4MgDPN9ZGz5abwHNkHrGq3uX/f6pQ=";
    };
    
    nativeBuildInputs = [ 
      prev.makeWrapper 
      prev.uv 
      prev.python3Packages.pip
    ];
    
    dontBuild = true;
    
    propagatedBuildInputs = with prev.python3Packages; [
      aiohttp numpy pillow psutil pyyaml safetensors scipy
      tqdm transformers gitpython opencv4 piexif numba
      pip
    ] ++ [ prev.uv ];
    
    installPhase = ''
      runHook preInstall
      
      mkdir -p $out/{bin,lib/comfyui}
      cp -r ./ $out/lib/comfyui/
      
      # Create wrapper that sets up proper Python environment
      makeWrapper ${prev.python3}/bin/python $out/bin/comfyui \
        --add-flags "$out/lib/comfyui/main.py" \
        --prefix PATH : ${prev.uv}/bin:${prev.python3Packages.pip}/bin \
        --set PIP_USER "1" \
        --set UV_SYSTEM_PYTHON "1" \
        --unset VIRTUAL_ENV
      
      runHook postInstall
    '';
    
    meta = with prev.lib; {
      description = "ComfyUI with Intel XPU support";
      homepage = "https://github.com/comfyanonymous/ComfyUI";
      license = licenses.gpl3Only;
      platforms = platforms.all;
    };
  };
}
