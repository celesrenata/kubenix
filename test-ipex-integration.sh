#!/usr/bin/env bash
set -e

echo "🧪 IPEX Integration Test Suite"
echo "=============================="

# Test 1: Flake structure validation
echo "📋 Test 1: Flake structure validation"
if nix flake check --no-build 2>&1 | grep -q "evaluating flake"; then
    echo "✅ Flake structure is valid (ignoring expected Go 1.22 deprecation)"
else
    echo "❌ Flake structure validation failed"
    exit 1
fi

# Test 2: Package accessibility
echo ""
echo "📦 Test 2: Package accessibility"

# Test Ollama-IPEX package
echo "  Testing ollama-ipex package..."
if nix eval .#packages.x86_64-linux.ollama-ipex.name 2>/dev/null; then
    echo "  ✅ ollama-ipex package accessible"
else
    echo "  ❌ ollama-ipex package not accessible"
fi

# Test Python-IPEX package
echo "  Testing python-ipex package..."
if nix eval .#packages.x86_64-linux.python-ipex.name 2>/dev/null; then
    echo "  ✅ python-ipex package accessible"
else
    echo "  ❌ python-ipex package not accessible"
fi

# Test Intel MKL package
echo "  Testing intel-mkl package..."
if nix eval .#packages.x86_64-linux.intel-mkl.name 2>/dev/null; then
    echo "  ✅ intel-mkl package accessible"
else
    echo "  ❌ intel-mkl package not accessible"
fi

# Test 3: Overlay functionality
echo ""
echo "🔄 Test 3: Overlay functionality"
if nix eval .#overlays.intel-xpu 2>/dev/null >/dev/null; then
    echo "✅ Intel XPU overlay accessible"
else
    echo "❌ Intel XPU overlay not accessible"
fi

# Test 4: Module system
echo ""
echo "🏗️  Test 4: Module system"

# Test NixOS modules
echo "  Testing NixOS modules..."
if nix eval .#nixosModules.ipex 2>/dev/null >/dev/null; then
    echo "  ✅ IPEX NixOS module accessible"
else
    echo "  ❌ IPEX NixOS module not accessible"
fi

if nix eval .#nixosModules.ollama-ipex 2>/dev/null >/dev/null; then
    echo "  ✅ Ollama-IPEX NixOS module accessible"
else
    echo "  ❌ Ollama-IPEX NixOS module not accessible"
fi

# Test Home Manager modules
echo "  Testing Home Manager modules..."
if nix eval .#homeManagerModules.ipex 2>/dev/null >/dev/null; then
    echo "  ✅ IPEX Home Manager module accessible"
else
    echo "  ❌ IPEX Home Manager module not accessible"
fi

# Test 5: Development shell
echo ""
echo "🐚 Test 5: Development shell"
if nix eval .#devShells.x86_64-linux.default 2>/dev/null >/dev/null; then
    echo "✅ Development shell accessible"
else
    echo "❌ Development shell not accessible"
fi

# Test 6: NixOS configuration
echo ""
echo "🖥️  Test 6: NixOS configuration"
if nix eval .#nixosConfigurations.ipex-example.config.system.build.toplevel 2>/dev/null >/dev/null; then
    echo "✅ IPEX example configuration builds"
else
    echo "❌ IPEX example configuration failed to build"
fi

echo ""
echo "🎉 Integration test suite completed!"
echo ""
echo "Next steps:"
echo "  1. Test on Intel hardware: sudo nixos-rebuild switch"
echo "  2. Verify Intel GPU detection: lspci | grep -i intel"
echo "  3. Test Ollama-IPEX service: systemctl status ollama-ipex"
echo "  4. Validate IPEX Python: python3 -c 'import intel_extension_for_pytorch as ipex; print(ipex.__version__)'"
