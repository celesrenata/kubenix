# IPEX Integration into Main NixOS System

## Current Situation
- **Main system**: `~/sources/nixos.works/` (your actual NixOS config with kubenix)
- **IPEX project**: `~/sources/nixos/` (our Intel IPEX integration work)
- **Problem**: ComfyUI has Intel IPEX dependencies but system lacks IPEX services

## Integration Steps

### 1. Add IPEX Flake Input to Main System

Add to your `~/sources/nixos.works/flake.nix` inputs:

```nix
inputs = {
  # ... existing inputs ...
  
  # Intel IPEX integration
  ipex-flake = { 
    url = "path:../nixos";  # Point to our IPEX work
    inputs.nixpkgs.follows = "nixpkgs";
  };
};
```

### 2. Add IPEX to Outputs Parameters

```nix
outputs = inputs@{ nixpkgs, nixpkgs-stable, nixpkgs-unstable, anyrun, home-manager, dream2nix, nixos-hardware, uniclip, i915-sriov, ipex-flake, ... }:
```

### 3. Import IPEX Modules in System Configuration

In your system modules list, add:

```nix
modules = [
  # ... existing modules ...
  
  # Intel IPEX integration
  ipex-flake.nixosModules.ipex
  ipex-flake.nixosModules.comfyui-ipex
  
  # Apply Intel XPU overlay
  { nixpkgs.overlays = [ ipex-flake.overlays.intel-xpu ]; }
  
  # ... rest of config ...
];
```

### 4. Enable IPEX Services in Configuration

Add to your system configuration:

```nix
{
  # Enable Intel IPEX support
  services.ipex = {
    enable = true;
    autoDetectHardware = true;
    devices = [ "gpu" "cpu" ];
    optimization = "balanced";
  };

  # Enable ComfyUI with Intel IPEX
  services.comfyui-ipex = {
    enable = true;
    host = "127.0.0.1";
    port = 8188;
    acceleration = "auto";
  };

  # Add Intel GPU tools
  environment.systemPackages = with pkgs; [
    intel-gpu-tools
    libva-utils
    # Access to our IPEX packages
    ipex-benchmarks
    comfyui-ipex
  ];
}
```

### 5. Rebuild System

```bash
cd ~/sources/nixos.works
sudo nixos-rebuild switch --flake .
```

## Expected Results After Integration

### ✅ **System Level**
- Intel GPU drivers properly loaded
- Intel IPEX environment variables set
- Intel XPU device detection working

### ✅ **ComfyUI Level**  
- `comfyui-ipex` available system-wide
- Intel XPU device count > 0 (instead of "zero!")
- Automatic Intel GPU acceleration

### ✅ **Testing Commands**
```bash
# Test Intel GPU detection
intel_gpu_top -l 1

# Test ComfyUI with Intel XPU
comfyui-ipex --help-gpu
comfyui-xpu  # Force Intel XPU

# Test IPEX benchmarks
ipex-benchmark --quick
```

## Why This Fixes XPU Detection

**Current Issue**: ComfyUI has Intel IPEX libraries but system lacks:
- Intel GPU driver configuration
- IPEX environment variables  
- Intel XPU device permissions
- System-level Intel GPU setup

**After Integration**: Full stack working:
- **Hardware**: Intel Arc GPU (✅ already present)
- **Drivers**: Intel GPU drivers (✅ will be configured)  
- **IPEX Stack**: Intel PyTorch + IPEX (✅ already in ComfyUI)
- **System Integration**: IPEX services (✅ will be enabled)
- **Applications**: ComfyUI with Intel XPU (✅ ready to test)

## Alternative: Test Without System Integration

If you want to test first without modifying your main system:

```bash
# Copy our IPEX work to a test location
cp -r ~/sources/nixos ~/sources/ipex-test

# Build and test the ipex-example system
cd ~/sources/ipex-test
sudo nixos-rebuild switch --flake .#ipex-example

# This will temporarily switch your system to our IPEX configuration
```

**Warning**: This will change your entire system configuration temporarily.

## Recommendation

I recommend the **full integration approach** - add IPEX as an input to your main system so you get Intel XPU support while keeping all your existing kubenix and other configurations.

The Intel Arc GPU is there and ready - we just need the system-level IPEX integration to make it accessible to ComfyUI! 🚀
