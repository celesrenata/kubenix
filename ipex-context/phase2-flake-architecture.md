# Phase 2: Flake Architecture Design

## Objective
Design a clean flake architecture that imports MordragT's IPEX work as a dependency and exposes IPEX-enabled packages for Ollama and ComfyUI integration.

## Flake Input Strategy

### Primary Input
```nix
inputs = {
  nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  mordrag-nixos = {
    url = "github:MordragT/nixos";
    inputs.nixpkgs.follows = "nixpkgs";
  };
};
```

### Dependency Management
- Follow nixpkgs for consistency
- Minimize input conflicts
- Ensure reproducible builds
- Handle Intel-specific package versions

## Package Exposure Strategy

### Overlay Design
```nix
overlays.default = final: prev: {
  # Intel XPU ecosystem
  intel-xpu = {
    # Core IPEX components
    python = mordrag-nixos.packages.${system}.intel-python;
    ipex = mordrag-nixos.packages.${system}.intel-python.pkgs.ipex;
    
    # Intel libraries
    mkl = mordrag-nixos.packages.${system}.intel-mkl;
    dpcpp = mordrag-nixos.packages.${system}.intel-dpcpp;
    
    # Applications
    ollama = mordrag-nixos.packages.${system}.ollama-sycl;
  };
  
  # Direct package aliases for convenience
  ollama-ipex = final.intel-xpu.ollama;
  python-ipex = final.intel-xpu.python;
};
```

### Module System Integration
```nix
nixosModules.ipex = {
  # Hardware detection
  # Driver configuration
  # Environment setup
  # Service definitions
};

homeManagerModules.ipex = {
  # User environment setup
  # Development tools
  # Application configurations
};
```

## Package Categories

### Core Infrastructure
- **intel-base**: MKL, TBB, DPC++, SYCL
- **intel-python**: Python environment with IPEX
- **intel-drivers**: Level Zero, OpenCL runtimes

### AI/ML Applications
- **ollama-ipex**: Ollama with Intel XPU support
- **comfyui-ipex**: ComfyUI with Intel optimizations (to be developed)
- **invokeai-ipex**: InvokeAI with XPU patches

### Development Tools
- **ipex-dev**: Development environment
- **profiling-tools**: Intel profiling and debugging tools
- **examples**: Sample applications and benchmarks

## Configuration Management

### Hardware Detection
```nix
services.ipex = {
  enable = true;
  autoDetectHardware = true;
  devices = [ "gpu" "cpu" ];
  optimization = "performance"; # or "balanced", "power"
};
```

### Application Integration
```nix
programs.ollama = {
  enable = true;
  backend = "ipex";
  acceleration = "auto";
};

programs.comfyui = {
  enable = true;
  backend = "ipex";
  models.path = "/path/to/models";
};
```

## Build System Considerations

### Cross-Platform Support
- x86_64-linux primary target
- Intel GPU hardware requirements
- CPU fallback mechanisms

### Caching Strategy
- Binary cache for Intel packages
- Reproducible build verification
- CI/CD integration points

## Integration Testing Framework

### Test Categories
1. **Package Build Tests**: Verify all packages build correctly
2. **Runtime Tests**: Basic functionality verification
3. **Performance Tests**: XPU acceleration validation
4. **Integration Tests**: Ollama + ComfyUI workflows

### Test Infrastructure
- Automated testing on Intel hardware
- Performance regression detection
- Compatibility matrix validation

## Deliverables
1. Complete flake.nix structure
2. Overlay and module definitions
3. Configuration schema design
4. Testing framework specification
5. Documentation templates

## Git Workflow
- **Working Branch**: `main`
- **Completion Tag**: `phase2-complete`
- **Commit Message Format**: `phase2: <description>`

### Phase Completion Criteria
- [ ] Flake structure implemented and building
- [ ] Overlay exposing intel-xpu packages
- [ ] NixOS and Home Manager modules working
- [ ] Basic configuration system functional
- [ ] Integration tests passing
- [ ] All deliverables committed and tagged

### Git Commands for Phase 2
```bash
# Regular commits during development
git add .
git commit -m "phase2: implement basic flake structure"
git commit -m "phase2: add intel-xpu overlay"
git commit -m "phase2: create nixos modules"

# Phase completion
git add .
git commit -m "phase2: complete flake architecture implementation"
git tag phase2-complete
```

## Next Phase Prerequisites
- Flake structure implementation
- Basic package exposure working
- Module system foundation
- Initial integration tests passing
- Git tag `phase2-complete` created
