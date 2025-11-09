{
  description = "Intel XPU Integration for NixOS with Native PyTorch 2.8+ Support";

  inputs = {
    nixpkgs             = { url = "github:nixos/nixpkgs/nixos-unstable"; };
    nixpkgs-unstable    = { url = "github:nixos/nixpkgs/nixos-unstable"; };
    nixpkgs-stable      = { url = "github:nixos/nixpkgs/nixos-24.11"; };
    home-manager        = { url = "github:nix-community/home-manager/master"; };
    anyrun              = { url = "github:Kirottu/anyrun"; };
    ags                 = { url = "github:Aylur/ags"; };
    nixos-hardware      = { url = "github:NixOS/nixos-hardware/master"; };
    dream2nix           = { url = "github:nix-community/dream2nix"; };
    uniclip             = { url = "github:celesrenata/uniclip"; };

    # MordragT's Intel IPEX packages
    mordrag-nixos = {
      url = "github:MordragT/nixos";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # follow relationships
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = inputs@{ self, nixpkgs, nixpkgs-stable, nixpkgs-unstable, anyrun, home-manager, dream2nix, nixos-hardware, uniclip, mordrag-nixos, ... }:
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
    # Intel XPU overlay for mainline PyTorch integration
    overlays.intel-xpu = final: prev: {
      # Kernel 6.18rc4 with native xe SR-IOV support
      inherit (import ./overlays/kernel.nix final prev) linux_6_18_rc4 linuxPackages_6_18_rc4;
      
      intel-xpu = {
        # Core Intel components from MordragT
        python = mordrag-nixos.packages.${final.system}.intel-python;
        mkl = mordrag-nixos.packages.${final.system}.intel-mkl;
        
        # Our applications with native PyTorch XPU support
        comfyui = final.comfyui-xpu;
        ollama = final.ollama-xpu;
      };
      
      # Applications using nixpkgs PyTorch with Intel optimizations
      comfyui-xpu = final.callPackage ./packages/comfyui-ipex {
        pytorch = final.python3Packages.torch;
        inherit (final) intel-mkl intel-tbb intel-dpcpp;
        comfyui-frontend-package = final.comfyui-frontend-package;
      };
      
      # ComfyUI frontend package
      comfyui-frontend-package = final.callPackage ./packages/comfyui-frontend.nix { };
      ollama-xpu = final.callPackage ./packages/ollama-ipex {
        inherit (final) intel-mkl;
      };
      ipex-benchmarks = final.callPackage ./packages/benchmarks {};
      
      # Add MordragT's Intel packages to system pkgs
      intel-mkl = mordrag-nixos.packages.${final.system}.intel-mkl;
      intel-tbb = mordrag-nixos.packages.${final.system}.intel-tbb;
      intel-dpcpp = mordrag-nixos.packages.${final.system}.intel-dpcpp;
      intel-dnnl = mordrag-nixos.packages.${final.system}.intel-dnnl;
      intel-sycl = mordrag-nixos.packages.${final.system}.intel-sycl;
    };

    # NixOS modules for Intel XPU integration
    nixosModules = {
      intel-xpu = import ./modules/nixos/ipex.nix;
      comfyui-xpu = import ./modules/nixos/comfyui-ipex.nix;
      comfyui-user = import ./modules/nixos/comfyui-user.nix;
      xe-sriov = import ./modules/nixos/xe-sriov.nix;
    };

    # Home Manager modules
    homeManagerModules = {
      intel-xpu = import ./modules/home-manager/ipex.nix;
    };

    # Package outputs
    packages.x86_64-linux = {
      # MordragT's packages (via overlay) - only working ones
      python-ipex = mordrag-nixos.packages.x86_64-linux.intel-python;
      intel-mkl = mordrag-nixos.packages.x86_64-linux.intel-mkl;
      
      # Our custom packages using nixpkgs PyTorch with Intel optimizations
      comfyui-xpu = pkgs.callPackage ./packages/comfyui-ipex {
        pytorch = pkgs.python3Packages.torch;
        intel-mkl = mordrag-nixos.packages.x86_64-linux.intel-mkl;
        intel-tbb = mordrag-nixos.packages.x86_64-linux.intel-tbb;
        intel-dpcpp = mordrag-nixos.packages.x86_64-linux.intel-dpcpp;
        comfyui-frontend-package = self.packages.x86_64-linux.comfyui-frontend-package;
      };
      
      # ComfyUI frontend package
      comfyui-frontend-package = pkgs.callPackage ./packages/comfyui-frontend.nix { };
      ollama-xpu = pkgs.callPackage ./packages/ollama-ipex {
        intel-mkl = mordrag-nixos.packages.x86_64-linux.intel-mkl;
      };
      
      # Benchmarking and testing tools
      ipex-benchmarks = pkgs.callPackage ./packages/benchmarks {
        intel-xpu = pkgs.intel-xpu;
      };
    };

    # System configurations
    nixosConfigurations = {
      # KubeVirt GPU workload VM with IPEX integration
      kubenix = lib.nixosSystem {
        inherit system;
        specialArgs = { inherit pkgs-stable pkgs-unstable; };
        modules = [
          # Allow unfree packages for Intel GPU firmware
          { 
            nixpkgs.config.allowUnfree = true;
            nixpkgs.config.permittedInsecurePackages = [
              "openssl-1.1.1w"
            ];
          }
          
          # Add necessary overlays including kernel overlay
          { nixpkgs.overlays = [ 
            (import ./overlays/kernel.nix)  # Kernel 6.18rc4 overlay
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
          
          # Native xe SR-IOV support (replaces i915-sriov experimental driver)
          self.nixosModules.xe-sriov
          
          # Intel XPU integration with mainline PyTorch 2.8+
          self.nixosModules.intel-xpu
          self.nixosModules.comfyui-xpu
          self.nixosModules.comfyui-user
          
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
        nodejs
        
        # Intel GPU tools
        intel-gpu-tools
        libva-utils
        
        # Our packages for testing
        self.packages.x86_64-linux.comfyui-xpu
        self.packages.x86_64-linux.ipex-benchmarks
      ];
      
      shellHook = ''
        echo "🚀 Intel XPU Development Environment (Simplified PyTorch)"
        echo "Available packages:"
        echo "  - comfyui-xpu: ComfyUI with nixpkgs PyTorch + Intel libraries"
        echo "  - ipex-benchmarks: Performance testing suite"
        echo ""
        echo "Intel GPU tools:"
        echo "  - intel_gpu_top: GPU monitoring"
        echo "  - vainfo: GPU capabilities"
        echo ""
        echo "Note: Using standard nixpkgs PyTorch with Intel MKL libraries"
      '';
    };
  };
}
