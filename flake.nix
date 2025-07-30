{
  description = "IPEX Integration Project - Intel XPU acceleration for Ollama and ComfyUI";

  inputs = {
    # Base inputs - using unstable for latest Intel GPU drivers
    # Note: Intel GPU support requires recent drivers (25.11+ when available)
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixpkgs-stable.url = "github:nixos/nixpkgs/nixos-25.05";
    home-manager = {
      url = "github:nix-community/home-manager/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    
    # MordragT's IPEX implementation
    mordrag-nixos = {
      url = "github:MordragT/nixos";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    
    # Your existing inputs
    anyrun.url = "github:Kirottu/anyrun";
    ags.url = "github:Aylur/ags";
    nixos-hardware.url = "github:NixOS/nixos-hardware/master";
    dream2nix.url = "github:nix-community/dream2nix";
    uniclip.url = "github:celesrenata/uniclip";
    i915-sriov.url = "github:strongtz/i915-sriov-dkms";
  };

  outputs = inputs@{ 
    nixpkgs, nixpkgs-stable, home-manager, mordrag-nixos,
    anyrun, ags, nixos-hardware, dream2nix, uniclip, i915-sriov,
    ...
  }:
  let
    system = "x86_64-linux";
    lib = nixpkgs.lib;

    # Your existing package sets
    pkgs-stable = import nixpkgs-stable {
      inherit system;
      config = {
        allowUnfree = true;
        permittedInsecurePackages = [
          "python-2.7.18.7"
          "openssl-1.1.1w"
        ];
      };
    };

    pkgs-unstable = import nixpkgs {
      inherit system;
      config.allowUnfree = true;
      overlays = [
        (import ./overlays/jetbrains-toolbox.nix)
      ];
    };

    # Main package set with IPEX integration
    pkgs = import nixpkgs {
      inherit system;
      config = {
        allowUnfree = true;
        allowUnfreePredicate = pkg: builtins.elem (lib.getName pkg) [ "vscode" ];
        allowUnsupportedSystem = true;
      };
      overlays = [
        # Your existing overlays
        (import ./overlays/debugpy.nix)
        (import ./overlays/materialyoucolor.nix)
        (import ./overlays/end-4-dots.nix)
        (import ./overlays/wofi-calc.nix)
        (import ./overlays/kernel.nix)
        (import ./overlays/intel-firmware.nix)
        (import ./overlays/xrdp.nix)
        (import ./overlays/xorgxrdp-glamor.nix)
        
        # IPEX overlay
        (import ./overlays/intel-xpu.nix { inherit mordrag-nixos; })
      ];
    };
  in
  {
    # Package overlays
    overlays = {
      default = import ./overlays/intel-xpu.nix { inherit mordrag-nixos; };
      intel-xpu = import ./overlays/intel-xpu.nix { inherit mordrag-nixos; };
    };

    # Packages exposed by this flake
    packages.${system} = {
      # Direct access to MordragT's IPEX packages
      ollama-ipex = mordrag-nixos.packages.${system}.ollama-sycl;
      python-ipex = mordrag-nixos.packages.${system}.intel-python;
      
      # Intel base libraries
      intel-mkl = mordrag-nixos.packages.${system}.intel-mkl;
      intel-dpcpp = mordrag-nixos.packages.${system}.intel-dpcpp;
      
      # Our custom packages
      comfyui-ipex = pkgs.callPackage ./packages/comfyui-ipex {};
      
      # ComfyUI custom nodes
      comfyui-controlnet-aux = pkgs.callPackage ./packages/comfyui-nodes/controlnet-aux {};
      comfyui-upscaling = pkgs.callPackage ./packages/comfyui-nodes/upscaling {};
      
      # Benchmarking and testing tools
      ipex-benchmarks = pkgs.callPackage ./packages/benchmarks {};
    };

    # NixOS modules
    nixosModules = {
      ipex = import ./modules/nixos/ipex.nix;
      ollama-ipex = import ./modules/nixos/ollama-ipex.nix;
      comfyui-ipex = import ./modules/nixos/comfyui-ipex.nix;
    };

    # Home Manager modules  
    homeManagerModules = {
      ipex = import ./modules/home-manager/ipex.nix;
      comfyui-ipex = import ./modules/home-manager/comfyui-ipex.nix;
      # ollama-ipex = import ./modules/home-manager/ollama-ipex.nix;  # Phase 4
    };

    # Your existing NixOS configurations with IPEX integration
    nixosConfigurations = {
      # Your existing kubenix configuration with IPEX support
      kubenix = nixpkgs.lib.nixosSystem {
        inherit system;
        pkgs = pkgs;
        specialArgs = {
          inherit inputs pkgs-stable pkgs-unstable;
        };
        modules = [
          # Your existing modules
          ./configuration.nix
          ./remote-build.nix
          ./hardware-configuration.nix
          ./kubenix/boot.nix
          ./kubenix/remote-build.nix
          ./kubenix/graphics.nix
          ./kubenix/networking.nix
          ./kubenix/virtualisation.nix
          ./kubenix/xrdp-drm.nix
          
          # Intel SR-IOV support
          i915-sriov.nixosModules.default
          
          # IPEX modules
          (import ./modules/nixos/ipex.nix)
          (import ./modules/nixos/ollama-ipex.nix)
          
          # Anyrun integration
          {
            environment.systemPackages = with pkgs; [
              anyrun.packages.${system}.anyrun
            ];
          }
          
          # Home Manager with IPEX support
          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.extraSpecialArgs = {
              inherit inputs pkgs-stable pkgs-unstable;
            };
            home-manager.users.celes = import ./home.nix;
          }
        ];
      };
      
      # IPEX-focused example configuration
      ipex-example = nixpkgs.lib.nixosSystem {
        inherit system;
        modules = [
          # Apply the Intel XPU overlay
          { nixpkgs.overlays = [ (import ./overlays/intel-xpu.nix { inherit mordrag-nixos; }) ]; }
          
          (import ./modules/nixos/ipex.nix)
          # (import ./modules/nixos/ollama-ipex.nix)  # Disabled due to Go 1.22 issue
          {
            # Basic configuration for IPEX testing
            boot.loader.systemd-boot.enable = true;
            boot.loader.efi.canTouchEfiVariables = true;
            
            # Required filesystem configuration
            fileSystems."/" = {
              device = "/dev/disk/by-label/nixos";
              fsType = "ext4";
            };
            
            fileSystems."/boot" = {
              device = "/dev/disk/by-label/boot";
              fsType = "vfat";
            };
            
            networking.hostName = "ipex-example";
            
            # Enable IPEX services
            services.ipex.enable = true;
            # services.ollama-ipex.enable = true;  # Disabled due to Go 1.22 issue
            
            # Add Intel GPU tools for debugging and monitoring
            environment.systemPackages = with pkgs; [
              intel-gpu-tools
              libva-utils
            ];
            
            users.users.user = {
              isNormalUser = true;
              extraGroups = [ "wheel" "render" "video" ];
            };
            
            system.stateVersion = "24.05";
          }
        ];
      };
    };

    # Development shell
    devShells.${system}.default = pkgs.mkShell {
      buildInputs = with pkgs; [
        # Development tools
        git
        nix-tree
        nix-output-monitor
        
        # IPEX development
        intel-xpu.python
        
        # ComfyUI development
        comfyui-ipex
        ipex-benchmarks
        
        # Your existing tools
        anyrun.packages.${system}.anyrun
      ];
      
      shellHook = ''
        echo "IPEX Integration Development Environment"
        echo "Current phase: $(git describe --tags --always 2>/dev/null || echo 'phase3-development')"
        echo ""
        echo "Available IPEX commands:"
        echo "  nix build .#ollama-ipex         # Build Ollama with IPEX"
        echo "  nix build .#python-ipex         # Build Intel Python environment"
        echo "  nix build .#comfyui-ipex        # Build ComfyUI with IPEX"
        echo "  nix flake check                 # Validate flake"
        echo ""
        echo "ComfyUI commands:"
        echo "  comfyui-ipex --listen 0.0.0.0   # Start ComfyUI with Intel XPU"
        echo "  ipex-benchmark                  # Run performance benchmarks"
        echo ""
        echo "Test IPEX installation:"
        echo "  python3 -c 'import intel_extension_for_pytorch as ipex; print(f\"IPEX {ipex.__version__} ready\")'"
        echo ""
      '';
    };
  };
}
