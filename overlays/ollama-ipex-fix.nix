final: prev: {
  # Fix MordragT's Ollama package by overriding the Go version
  ollama-ipex = 
    let
      # Get MordragT's ollama-sycl package
      mordragPkgs = import (builtins.fetchGit {
        url = "https://github.com/MordragT/nixos";
        ref = "main";
      }) { 
        inherit (final) system; 
        config.allowUnfree = true;
      };
    in
    # Override the buildGoModule to use current Go version
    mordragPkgs.ollama-sycl.overrideAttrs (oldAttrs: {
      # Use current buildGoModule instead of buildGo122Module
      nativeBuildInputs = (oldAttrs.nativeBuildInputs or []) ++ [
        final.go
      ];
      
      # Update the Go module builder
      buildPhase = ''
        runHook preBuild
        
        export GOCACHE=$TMPDIR/go-cache
        export GOPATH="$TMPDIR/go"
        export GOPROXY=off
        export GOSUMDB=off
        export CGO_ENABLED=1
        
        # Intel SYCL specific environment
        export GGML_SYCL=1
        export GGML_SYCL_F16=1
        
        # Build with current Go version
        go build -buildmode=pie -trimpath -mod=readonly -modcacherw \
          -ldflags "-s -w -X=github.com/ollama/ollama/version.Version=${oldAttrs.version or "0.5.4"}" \
          .
        
        runHook postBuild
      '';
      
      meta = (oldAttrs.meta or {}) // {
        description = "Ollama with Intel IPEX/SYCL support (Go version fixed)";
        broken = false;
      };
    });
}
