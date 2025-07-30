# Architecture Overview

This document provides a comprehensive overview of the IPEX Integration project architecture, designed for developers who want to understand, extend, or contribute to the system.

## Project Structure

```
ipex-flake/
├── flake.nix                    # Main flake definition
├── overlays/                    # Package overlays
│   └── intel-xpu.nix           # Intel XPU ecosystem overlay
├── modules/                     # NixOS and Home Manager modules
│   ├── nixos/                  # System-level modules
│   │   ├── ipex.nix            # Base IPEX configuration
│   │   ├── ollama-ipex.nix     # Ollama service module
│   │   └── comfyui-ipex.nix    # ComfyUI service module
│   └── home-manager/           # User-level modules
│       ├── ipex.nix            # IPEX development environment
│       └── comfyui-ipex.nix    # ComfyUI development setup
├── packages/                   # Custom package definitions
│   ├── comfyui-ipex/          # ComfyUI with IPEX support
│   ├── comfyui-nodes/         # Custom node packages
│   │   ├── controlnet-aux/    # ControlNet auxiliary nodes
│   │   └── upscaling/         # Upscaling models
│   └── benchmarks/            # Performance benchmarking tools
├── examples/                  # Configuration examples
│   ├── production/           # Production deployment configs
│   ├── monitoring/           # Monitoring and alerting
│   └── maintenance/          # Automated maintenance
└── docs/                     # Documentation
    ├── user/                # User guides
    ├── developer/           # Developer documentation
    └── deployment/          # Deployment guides
```

## Core Architecture Principles

### 1. Modular Design
- **Separation of Concerns**: Each component has a specific responsibility
- **Composability**: Modules can be combined in different ways
- **Extensibility**: Easy to add new services and features
- **Reusability**: Components can be used across different configurations

### 2. Dependency Management
- **Flake Inputs**: Clean dependency specification with version pinning
- **Overlay System**: Controlled package customization and integration
- **Follow Relationships**: Consistent nixpkgs versions across dependencies
- **Isolation**: Intel packages isolated in scoped overlays

### 3. Configuration Management
- **Declarative**: All configuration expressed as Nix code
- **Type Safety**: Strong typing with validation and error checking
- **Documentation**: Self-documenting configuration options
- **Defaults**: Sensible defaults with easy customization

## Component Architecture

### Flake Structure

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    mordrag-nixos = {
      url = "github:MordragT/nixos";
      inputs.nixpkgs.follows = "nixpkgs";  # Consistency
    };
  };

  outputs = { nixpkgs, mordrag-nixos, ... }: {
    # Package exposure
    packages.x86_64-linux = {
      # Direct MordragT packages
      ollama-ipex = mordrag-nixos.packages.x86_64-linux.ollama-sycl;
      python-ipex = mordrag-nixos.packages.x86_64-linux.intel-python;
      
      # Our custom packages
      comfyui-ipex = pkgs.callPackage ./packages/comfyui-ipex {};
    };
    
    # Module system
    nixosModules = { /* ... */ };
    homeManagerModules = { /* ... */ };
    
    # Overlay system
    overlays.intel-xpu = import ./overlays/intel-xpu.nix;
  };
}
```

### Overlay System

The overlay system provides a clean interface to the Intel XPU ecosystem:

```nix
# overlays/intel-xpu.nix
{ mordrag-nixos }:

final: prev: {
  intel-xpu = {
    # Core IPEX components from MordragT
    python = mordrag-nixos.packages.${final.system}.intel-python;
    ipex = mordrag-nixos.packages.${final.system}.intel-python.pkgs.ipex;
    mkl = mordrag-nixos.packages.${final.system}.intel-mkl;
    
    # Our custom applications
    comfyui = final.comfyui-ipex;
    ollama = final.ollama-ipex;
  };
  
  # Convenient aliases
  comfyui-ipex = final.callPackage ./packages/comfyui-ipex {};
}
```

### Module System

#### NixOS Modules

NixOS modules provide system-level configuration:

```nix
# modules/nixos/ipex.nix
{ config, lib, pkgs, ... }:

{
  options.services.ipex = {
    enable = mkEnableOption "Intel IPEX support";
    devices = mkOption {
      type = types.listOf (types.enum [ "gpu" "cpu" ]);
      default = [ "gpu" "cpu" ];
    };
    # ... more options
  };
  
  config = mkIf config.services.ipex.enable {
    # Hardware configuration
    hardware.graphics.enable = true;
    hardware.graphics.extraPackages = [ /* Intel drivers */ ];
    
    # Environment setup
    environment.variables = { /* Intel GPU vars */ };
    
    # User groups
    users.groups.render = {};
  };
}
```

#### Home Manager Modules

Home Manager modules provide user-level configuration:

```nix
# modules/home-manager/ipex.nix
{ config, lib, pkgs, ... }:

{
  options.programs.ipex = {
    enable = mkEnableOption "IPEX development environment";
    development.enable = mkEnableOption "development tools";
  };
  
  config = mkIf config.programs.ipex.enable {
    home.packages = [ pkgs.intel-xpu.python ];
    programs.vscode = { /* VS Code config */ };
    home.sessionVariables = { /* Environment vars */ };
  };
}
```

## Package Development

### Custom Package Structure

```nix
# packages/comfyui-ipex/default.nix
{ lib, buildPythonApplication, fetchFromGitHub, intel-xpu, ... }:

buildPythonApplication rec {
  pname = "comfyui-ipex";
  version = "2024-07-30";
  
  src = fetchFromGitHub {
    owner = "comfyanonymous";
    repo = "ComfyUI";
    # ...
  };
  
  propagatedBuildInputs = [
    intel-xpu.python.pkgs.ipex  # Use Intel-optimized packages
    intel-xpu.python.pkgs.torch
    # ... other dependencies
  ];
  
  patches = [
    ./01-intel-xpu-device-support.patch
    ./02-memory-optimization.patch
    ./03-model-loading.patch
  ];
  
  # Custom installation and wrapping
  installPhase = ''
    # Install ComfyUI
    # Create wrapper with Intel GPU environment
  '';
}
```

### Patch Development

Intel XPU support is added through targeted patches:

#### Device Detection Patch
```diff
# 01-intel-xpu-device-support.patch
+# Intel XPU support
+def is_intel_xpu_available():
+    return IPEX_AVAILABLE and hasattr(torch, 'xpu') and torch.xpu.is_available()
+
+INTEL_XPU_AVAILABLE = is_intel_xpu_available()

 def get_torch_device():
     if args.cpu:
         return torch.device("cpu")
+    elif INTEL_XPU_AVAILABLE:
+        return torch.device("xpu")
     elif torch.cuda.is_available():
         return torch.device("cuda")
```

#### Memory Management Patch
```diff
# 02-memory-optimization.patch
+    elif dev.type == "xpu":
+        # Intel XPU memory management
+        try:
+            mem_free_total = torch.xpu.get_device_properties(dev.index).total_memory
+            mem_free_torch = mem_free_total - torch.xpu.memory_allocated(dev.index)
+            return mem_free_total, mem_free_torch
+        except:
+            return 4 * 1024**3, 2 * 1024**3  # Conservative fallback
```

## Service Architecture

### Service Configuration

Services are configured through comprehensive option sets:

```nix
services.comfyui-ipex = {
  enable = true;
  
  # Network configuration
  host = "127.0.0.1";
  port = 8188;
  
  # Model management
  models = {
    path = "/var/lib/comfyui/models";
    autoDownload = true;
    cache.enable = true;
  };
  
  # Performance optimization
  optimization = {
    level = "O1";         # IPEX optimization level
    precision = "fp16";   # Model precision
    jitCompile = true;    # JIT compilation
  };
  
  # Custom nodes
  nodes.enable = [ "controlnet-aux" "upscaling" ];
};
```

### Service Implementation

Services are implemented as systemd units with proper security:

```nix
systemd.services.comfyui-ipex = {
  description = "ComfyUI with Intel IPEX acceleration";
  wantedBy = [ "multi-user.target" ];
  after = [ "network.target" "ipex.service" ];
  
  environment = {
    ZES_ENABLE_SYSMAN = "1";
    ONEAPI_DEVICE_SELECTOR = "opencl:*";
    # ... other Intel GPU variables
  };
  
  serviceConfig = {
    Type = "simple";
    User = "comfyui";
    Group = "comfyui";
    
    # Security hardening
    NoNewPrivileges = true;
    PrivateTmp = true;
    ProtectSystem = "strict";
    
    # Resource limits
    MemoryMax = "16G";
    CPUQuota = "800%";
  };
};
```

## Performance Architecture

### Benchmarking System

The benchmarking system provides comprehensive performance testing:

```python
# packages/benchmarks/benchmark.py
class IPEXBenchmark:
    def __init__(self):
        self.device = self.detect_device()  # Auto-detect best device
        
    def benchmark_tensor_ops(self):
        # Matrix multiplication benchmarks
        
    def benchmark_conv_ops(self):
        # CNN inference benchmarks
        
    def benchmark_stable_diffusion_simulation(self):
        # SD-like workload benchmarks
```

### Optimization Levels

IPEX optimization is configurable at multiple levels:

1. **O0**: No optimization (debugging)
2. **O1**: Basic optimization (default)
3. **O2**: Aggressive optimization (production)
4. **O3**: Maximum optimization (experimental)

### Precision Control

Multiple precision modes for different use cases:

- **fp32**: Full precision (highest quality, most memory)
- **fp16**: Half precision (balanced quality/performance)
- **bf16**: Brain float 16 (good for training)
- **int8**: Integer quantization (fastest, least memory)

## Monitoring and Maintenance

### Health Monitoring

Automated health checks monitor system status:

```bash
# Health check components
- Intel GPU availability and utilization
- Service responsiveness (API endpoints)
- System resources (CPU, memory, disk)
- Network connectivity
- Performance benchmarks (periodic)
```

### Automated Maintenance

Maintenance tasks run automatically:

```bash
# Cleanup tasks
- Log rotation and cleanup
- Temporary file cleanup
- Model cache management
- Nix store garbage collection

# Update tasks
- System updates (configurable)
- Service restarts
- Validation checks
```

## Extension Points

### Adding New Services

To add a new AI service:

1. **Create Package**: Define in `packages/new-service/`
2. **Add Module**: Create NixOS module in `modules/nixos/`
3. **Update Overlay**: Add to `overlays/intel-xpu.nix`
4. **Add to Flake**: Expose in `flake.nix`

### Custom Node Development

For ComfyUI custom nodes:

1. **Package Definition**: Create in `packages/comfyui-nodes/`
2. **Intel XPU Patches**: Add device support patches
3. **Integration**: Add to ComfyUI module configuration
4. **Testing**: Include in benchmark suite

### Monitoring Extensions

To add new monitoring:

1. **Metrics Collection**: Add to health check script
2. **Grafana Dashboard**: Update dashboard JSON
3. **Alerting Rules**: Add to alerting configuration
4. **Documentation**: Update monitoring guide

## Development Workflow

### Setting Up Development Environment

```bash
# Clone repository
git clone https://github.com/yourusername/ipex-flake.git
cd ipex-flake

# Enter development shell
nix develop

# Check current phase
git describe --tags --always
```

### Testing Changes

```bash
# Validate flake structure
nix flake check

# Test package builds
nix build .#comfyui-ipex

# Run integration tests
./test-comfyui-integration.sh

# Run benchmarks
nix run .#ipex-benchmarks -- --quick
```

### Contributing Guidelines

1. **Follow Phases**: Respect the 4-phase development approach
2. **Test Thoroughly**: Ensure all tests pass
3. **Document Changes**: Update relevant documentation
4. **Commit Messages**: Use descriptive commit messages
5. **Git Tags**: Tag phase completions appropriately

## Security Considerations

### Service Isolation

- **User Isolation**: Each service runs as dedicated user
- **Filesystem Isolation**: Restricted filesystem access
- **Network Isolation**: Controlled network access
- **Resource Limits**: CPU and memory constraints

### Production Hardening

- **Firewall Rules**: Restrict network access
- **SSL/TLS**: Encrypt network communications
- **Authentication**: Implement access controls
- **Monitoring**: Comprehensive security monitoring
- **Updates**: Automated security updates

## Performance Considerations

### Intel GPU Optimization

- **Driver Configuration**: Proper Intel GPU driver setup
- **Memory Management**: Efficient GPU memory usage
- **Kernel Parameters**: Optimized kernel configuration
- **Environment Variables**: Proper Intel GPU environment

### System Tuning

- **CPU Scheduling**: Optimized process scheduling
- **Memory Management**: Tuned memory parameters
- **I/O Scheduling**: Optimized disk I/O
- **Network Tuning**: Enhanced network performance

This architecture provides a solid foundation for Intel IPEX integration while maintaining flexibility for future extensions and optimizations.
