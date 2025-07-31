{
  description = "Intel IPEX Integration for NixOS with KubeVirt GPU Workloads";

  inputs = {
    nixpkgs             = { url = "github:nixos/nixpkgs/nixos-unstable"; };
    nixpkgs-unstable    = { url = "github:nixos/nixpkgs/nixos-unstable"; };
    nixpkgs-stable      = { url = "github:nixos/nixpkgs/nixos-25.05"; };
    home-manager        = { url = "github:nix-community/home-manager/master"; };
    anyrun              = { url = "github:Kirottu/anyrun"; };
    ags                 = { url = "github:Aylur/ags"; };
    nixos-hardware      = { url = "github:NixOS/nixos-hardware/master"; };
    dream2nix           = { url = "github:nix-community/dream2nix"; };
    uniclip             = { url = "github:celesrenata/uniclip"; };
    # Intel SR-IOV support - use as NixOS module
    i915-sriov          = { url = "github:strongtz/i915-sriov-dkms"; };

    # MordragT's Intel IPEX packages
    mordrag-nixos = {
      url = "github:MordragT/nixos";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # follow relationships
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = inputs@{ self, nixpkgs, nixpkgs-stable, nixpkgs-unstable, anyrun, home-manager, dream2nix, nixos-hardware, uniclip, i915-sriov, mordrag-nixos, ... }:
  let
    system = "x86_64-linux";
    lib    = nixpkgs.lib;

    pkgs = import nixpkgs {
      inherit system;
      config.allowUnfree = true;
    };

    pkgs-stable = import nixpkgs-stable {
      inherit system;
      config = {
        allowUnfree               = true;
        permittedInsecurePackages = [
          "electron-25.9.0"
        ];
      };
    };

    pkgs-unstable = import nixpkgs-unstable {
      inherit system;
      config = {
        allowUnfree               = true;
        permittedInsecurePackages = [
          "electron-25.9.0"
        ];
      };
    };
  in
  {
    # Intel XPU overlay for IPEX integration
    overlays.intel-xpu = final: prev: {
      intel-xpu = {
        # Core IPEX components from MordragT
        python = mordrag-nixos.packages.${final.system}.intel-python;
        mkl = mordrag-nixos.packages.${final.system}.intel-mkl;
        
        # Our applications with Intel IPEX support
        comfyui = final.comfyui-ipex;
        ollama = final.ollama-ipex;  # Now enabled with fixed Go version
      };
      
      # Direct access to our packages
      comfyui-ipex = final.callPackage ./packages/comfyui-ipex {
        inherit (final) ipex-llm intel-mkl intel-tbb intel-dpcpp;
      };
      ollama-ipex = final.callPackage ./packages/ollama-ipex {};  # Add our fixed Ollama
      ipex-benchmarks = final.callPackage ./packages/benchmarks {};
      
      # Add MordragT's Intel packages to system pkgs (prefer OneAPI versions)
      intel-mkl = mordrag-nixos.packages.${final.system}.intel-mkl;
      intel-tbb = mordrag-nixos.packages.${final.system}.intel-tbb;  # Use regular intel-tbb (has vars.sh)
      intel-dpcpp = mordrag-nixos.packages.${final.system}.intel-dpcpp;
      intel-dnnl = mordrag-nixos.packages.${final.system}.intel-dnnl;
      intel-sycl = mordrag-nixos.packages.${final.system}.intel-sycl;
      
      # Our custom packages
      ipex-llm = final.callPackage ./packages/ipex-llm.nix { 
        inherit (final) intel-mkl intel-tbb intel-dpcpp intel-dnnl jemalloc gperftools;
      };
    };

    # NixOS modules for IPEX integration
    nixosModules = {
      ipex = import ./modules/nixos/ipex.nix;
      comfyui-ipex = import ./modules/nixos/comfyui-ipex.nix;
    };

    # Home Manager modules
    homeManagerModules = {
      ipex = import ./modules/home-manager/ipex.nix;
    };

    # Package outputs
    packages.x86_64-linux = {
      # MordragT's packages (via overlay)
      python-ipex = mordrag-nixos.packages.x86_64-linux.intel-python;
      intel-mkl = mordrag-nixos.packages.x86_64-linux.intel-mkl;
      intel-dpcpp = mordrag-nixos.packages.x86_64-linux.intel-dpcpp;
      
      # Our custom packages
      comfyui-ipex = pkgs.callPackage ./packages/comfyui-ipex {
        ipex-llm = self.packages.x86_64-linux.ipex-llm;
        intel-mkl = mordrag-nixos.packages.x86_64-linux.intel-mkl;
        intel-tbb = mordrag-nixos.packages.x86_64-linux.intel-tbb;
        intel-dpcpp = mordrag-nixos.packages.x86_64-linux.intel-dpcpp;
      };
      ollama-ipex = pkgs.callPackage ./packages/ollama-ipex {};  # Fixed Ollama with Intel IPEX
      comfyui-controlnet-aux = pkgs.callPackage ./packages/comfyui-nodes/controlnet-aux {};
      comfyui-upscaling = pkgs.callPackage ./packages/comfyui-nodes/upscaling {};
      
      # Benchmarking and testing tools
      ipex-benchmarks = pkgs.callPackage ./packages/benchmarks {};
      
      # Intel IPEX-LLM (proper Nix derivation from source)
      ipex-llm = pkgs.callPackage ./packages/ipex-llm.nix { 
        intel-mkl = mordrag-nixos.packages.x86_64-linux.intel-mkl;
        intel-tbb = mordrag-nixos.packages.x86_64-linux.intel-tbb;
        intel-dpcpp = mordrag-nixos.packages.x86_64-linux.intel-dpcpp;
        intel-dnnl = mordrag-nixos.packages.x86_64-linux.intel-dnnl;
        jemalloc = pkgs.jemalloc;
        gperftools = pkgs.gperftools;
      };
    };

    # System configurations
    nixosConfigurations = {
      # Original IPEX example system
      ipex-example = lib.nixosSystem {
        inherit system;
        specialArgs = { inherit pkgs-stable pkgs-unstable; };
        modules = [
          ./examples/ipex-example/configuration.nix
          ./examples/ipex-example/hardware-configuration.nix
          
          # Apply Intel XPU overlay
          { nixpkgs.overlays = [ self.overlays.intel-xpu ]; }
          
          # IPEX modules
          self.nixosModules.ipex
          self.nixosModules.comfyui-ipex
          
          # Home Manager integration
          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.users.user = import ./examples/ipex-example/home.nix;
            home-manager.extraSpecialArgs = { inherit pkgs-stable pkgs-unstable; };
          }
        ];
      };

      # KubeVirt GPU workload VM with IPEX integration
      kubenix = lib.nixosSystem {
        inherit system;
        specialArgs = { inherit pkgs-stable pkgs-unstable; };
        modules = [
          # Allow unfree packages for Intel GPU firmware
          { 
            nixpkgs.config.allowUnfree = true;
          }
          
          # Add necessary overlays from original system
          { nixpkgs.overlays = [ 
            self.overlays.intel-xpu
            (import ./overlays/intel-firmware.nix)
            (import ./overlays/ollama-sycl-fix.nix)  # Fix MordragT's Ollama Go 1.22 issue
            (import ./overlays/end-4-dots.nix)
            (import ./overlays/wofi-calc.nix)
            (import ./overlays/xrdp.nix)
            (import ./overlays/xorgxrdp-glamor.nix)
          ]; }
          
          # Original kubenix system configuration (without K3s)
          ./configuration.nix
          ./hardware-configuration.nix
          ./kubenix/boot.nix
          ./kubenix/graphics.nix
          ./kubenix/networking.nix
          # ./kubenix/kubernetes.nix  # REMOVED: This VM is already IN a Kubernetes cluster!
          ./kubenix/virtualisation.nix
          ./kubenix/iscsi.nix
          ./kubenix/remote-build.nix
          ./kubenix/xrdp-drm.nix
          
          # Intel SR-IOV support as NixOS module
          i915-sriov.nixosModules.default
          
          # ADD: Intel IPEX integration
          self.nixosModules.ipex
          self.nixosModules.comfyui-ipex
          
          # Home Manager
          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.users.celes = import ./home.nix;
            home-manager.extraSpecialArgs = { 
              inherit pkgs-stable pkgs-unstable; 
              inherit inputs;
              inherit system;
            };
          }
        ];
      };
    };

    # Development environments
    devShells.x86_64-linux.default = pkgs.mkShell {
      buildInputs = with pkgs; [
        # Development tools
        git
        nix-prefetch-github
        
        # Intel GPU tools
        intel-gpu-tools
        libva-utils
        
        # Our packages for testing
        self.packages.x86_64-linux.comfyui-ipex
        self.packages.x86_64-linux.ipex-benchmarks
      ];
      
      shellHook = ''
        echo "🚀 Intel IPEX Development Environment"
        echo "Available packages:"
        echo "  - comfyui-ipex: ComfyUI with Intel XPU support"
        echo "  - ipex-benchmarks: Performance testing suite"
        echo ""
        echo "Intel GPU tools:"
        echo "  - intel_gpu_top: GPU monitoring"
        echo "  - vainfo: GPU capabilities"
      '';
    };
  };
}
