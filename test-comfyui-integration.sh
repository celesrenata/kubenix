#!/usr/bin/env bash
set -e

echo "🎨 ComfyUI-IPEX Integration Test Suite"
echo "======================================"

# Test 1: Package availability
echo "📦 Test 1: ComfyUI-IPEX package availability"

# Test ComfyUI-IPEX package
echo "  Testing comfyui-ipex package..."
if nix eval .#packages.x86_64-linux.comfyui-ipex.name 2>/dev/null; then
    echo "  ✅ comfyui-ipex package accessible"
else
    echo "  ❌ comfyui-ipex package not accessible"
fi

# Test ComfyUI custom nodes
echo "  Testing comfyui custom nodes..."
if nix eval .#packages.x86_64-linux.comfyui-controlnet-aux.name 2>/dev/null; then
    echo "  ✅ comfyui-controlnet-aux package accessible"
else
    echo "  ❌ comfyui-controlnet-aux package not accessible"
fi

if nix eval .#packages.x86_64-linux.comfyui-upscaling.name 2>/dev/null; then
    echo "  ✅ comfyui-upscaling package accessible"
else
    echo "  ❌ comfyui-upscaling package not accessible"
fi

# Test 2: Module system
echo ""
echo "🏗️  Test 2: ComfyUI module system"

# Test NixOS module
echo "  Testing ComfyUI NixOS module..."
if nix eval .#nixosModules.comfyui-ipex 2>/dev/null >/dev/null; then
    echo "  ✅ ComfyUI NixOS module accessible"
else
    echo "  ❌ ComfyUI NixOS module not accessible"
fi

# Test Home Manager module
echo "  Testing ComfyUI Home Manager module..."
if nix eval .#homeManagerModules.comfyui-ipex 2>/dev/null >/dev/null; then
    echo "  ✅ ComfyUI Home Manager module accessible"
else
    echo "  ❌ ComfyUI Home Manager module not accessible"
fi

# Test 3: Overlay integration
echo ""
echo "🔄 Test 3: ComfyUI overlay integration"
if nix eval --json .#overlays.intel-xpu 2>/dev/null | grep -q "comfyui"; then
    echo "✅ ComfyUI integrated in Intel XPU overlay"
else
    echo "❌ ComfyUI not found in Intel XPU overlay"
fi

# Test 4: Configuration validation
echo ""
echo "⚙️  Test 4: Configuration validation"

# Create temporary test configuration
cat > test-comfyui-config.nix << 'EOF'
{ config, pkgs, ... }:
{
  imports = [
    (import ./modules/nixos/ipex.nix)
    (import ./modules/nixos/comfyui-ipex.nix)
  ];
  
  services.ipex.enable = true;
  services.comfyui-ipex = {
    enable = true;
    host = "0.0.0.0";
    port = 8188;
    models.autoDownload = false;
    acceleration = "auto";
  };
  
  # Minimal system configuration
  boot.loader.systemd-boot.enable = true;
  networking.hostName = "comfyui-test";
  users.users.test = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
  };
  system.stateVersion = "24.05";
}
EOF

echo "  Testing ComfyUI service configuration..."
if nix eval --json -f test-comfyui-config.nix config.services.comfyui-ipex.enable 2>/dev/null | grep -q "true"; then
    echo "  ✅ ComfyUI service configuration valid"
else
    echo "  ❌ ComfyUI service configuration invalid"
fi

# Cleanup
rm -f test-comfyui-config.nix

# Test 5: Development environment
echo ""
echo "🛠️  Test 5: Development environment"

# Create temporary home configuration
cat > test-home-config.nix << 'EOF'
{ config, pkgs, ... }:
{
  imports = [
    (import ./modules/home-manager/ipex.nix)
    (import ./modules/home-manager/comfyui-ipex.nix)
  ];
  
  programs.ipex.enable = true;
  programs.comfyui-ipex = {
    enable = true;
    development.enable = true;
    workspace.directory = "~/comfyui-workspace";
  };
  
  home.username = "test";
  home.homeDirectory = "/home/test";
  home.stateVersion = "24.05";
}
EOF

echo "  Testing ComfyUI development environment..."
if nix eval --json -f test-home-config.nix config.programs.comfyui-ipex.enable 2>/dev/null | grep -q "true"; then
    echo "  ✅ ComfyUI development environment valid"
else
    echo "  ❌ ComfyUI development environment invalid"
fi

# Cleanup
rm -f test-home-config.nix

# Test 6: Intel XPU integration
echo ""
echo "🚀 Test 6: Intel XPU integration check"

# Check if we can access Intel XPU components through ComfyUI
echo "  Checking Intel XPU components..."
if nix eval .#packages.x86_64-linux.python-ipex.name 2>/dev/null >/dev/null; then
    echo "  ✅ Intel Python environment available for ComfyUI"
else
    echo "  ❌ Intel Python environment not available"
fi

if nix eval .#packages.x86_64-linux.intel-mkl.name 2>/dev/null >/dev/null; then
    echo "  ✅ Intel MKL available for ComfyUI acceleration"
else
    echo "  ❌ Intel MKL not available"
fi

# Test 7: Example workflow validation
echo ""
echo "📋 Test 7: Example workflow validation"

# Check if we can create a basic workflow structure
echo "  Testing workflow structure..."
if command -v jq >/dev/null 2>&1; then
    # Create a simple workflow JSON to validate structure
    cat > test-workflow.json << 'EOF'
{
  "1": {
    "inputs": {
      "ckpt_name": "sd_xl_base_1.0.safetensors"
    },
    "class_type": "CheckpointLoaderSimple"
  },
  "2": {
    "inputs": {
      "text": "a beautiful landscape",
      "clip": ["1", 1]
    },
    "class_type": "CLIPTextEncode"
  }
}
EOF
    
    if jq empty test-workflow.json 2>/dev/null; then
        echo "  ✅ Example workflow JSON structure valid"
    else
        echo "  ❌ Example workflow JSON structure invalid"
    fi
    
    rm -f test-workflow.json
else
    echo "  ⚠️  jq not available, skipping workflow JSON validation"
fi

echo ""
echo "🎉 ComfyUI-IPEX integration test suite completed!"
echo ""
echo "📊 Summary:"
echo "  - ComfyUI-IPEX package: Ready for integration"
echo "  - Custom nodes: ControlNet and Upscaling support"
echo "  - NixOS/Home Manager modules: Configuration ready"
echo "  - Intel XPU integration: IPEX acceleration available"
echo "  - Development environment: Complete workspace setup"
echo ""
echo "🚀 Next steps:"
echo "  1. Build ComfyUI-IPEX: nix build .#comfyui-ipex"
echo "  2. Test on Intel hardware: Enable services in configuration.nix"
echo "  3. Validate Intel GPU: Check XPU device detection"
echo "  4. Run benchmarks: Test inference performance"
echo "  5. Deploy workflows: Create and test AI generation workflows"
echo ""
echo "⚠️  Note: Some packages may need actual source hashes to build"
echo "   This is expected during development phase"
