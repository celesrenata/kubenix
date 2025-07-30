# Phase 3: ComfyUI Integration

## Objective
Develop ComfyUI integration with Intel IPEX support, leveraging the established IPEX infrastructure from MordragT's work.

## ComfyUI Analysis

### Current State Assessment
- ComfyUI typically runs on CUDA/ROCm
- PyTorch backend with custom nodes
- Model loading and inference pipeline
- Web interface and API

### IPEX Integration Requirements
- Intel XPU device detection
- IPEX-optimized PyTorch integration
- Memory management for Intel GPUs
- Custom node compatibility

## Integration Strategy

### Package Development
```nix
# pkgs/comfyui-ipex/default.nix
{ buildPythonApplication
, fetchFromGitHub
, intel-python
, ipex
, torch
, torchvision
, ...
}:

buildPythonApplication rec {
  pname = "comfyui-ipex";
  version = "latest";
  
  src = fetchFromGitHub {
    owner = "comfyanonymous";
    repo = "ComfyUI";
    # ... source details
  };
  
  propagatedBuildInputs = with intel-python.pkgs; [
    ipex
    torch
    torchvision
    # ... other dependencies
  ];
  
  patches = [
    ./01-ipex-device-support.patch
    ./02-xpu-memory-management.patch
    ./03-model-loading-optimization.patch
  ];
  
  # ... build configuration
}
```

### Patch Development Strategy

#### Device Detection Patch
- Modify device detection to recognize Intel XPU
- Add XPU to supported device list
- Implement device capability queries

#### Memory Management Patch
- Intel GPU memory allocation
- Unified memory handling
- Memory pool optimization

#### Model Loading Optimization
- IPEX model optimization hooks
- Quantization support
- Inference acceleration

### Custom Nodes Compatibility

#### Priority Nodes for IPEX Support
1. **ControlNet nodes**: Essential for advanced workflows
2. **Upscaling nodes**: Benefit from XPU acceleration
3. **Animation nodes**: Video processing acceleration
4. **Custom samplers**: Inference optimization

#### Compatibility Matrix
```nix
comfyui-nodes-ipex = {
  controlnet-aux = callPackage ./nodes/controlnet-aux {
    inherit (intel-python.pkgs) controlnet-aux;
  };
  
  upscaling = callPackage ./nodes/upscaling {
    # Intel-optimized upscaling models
  };
  
  animation = callPackage ./nodes/animation {
    # Video processing with XPU acceleration
  };
};
```

## Configuration System

### NixOS Module
```nix
services.comfyui = {
  enable = true;
  
  backend = {
    type = "ipex";
    device = "auto"; # or specific Intel GPU
    optimization = "performance";
  };
  
  models = {
    path = "/var/lib/comfyui/models";
    autoDownload = true;
    cache = {
      enable = true;
      size = "10GB";
    };
  };
  
  nodes = {
    enable = [ "controlnet-aux" "upscaling" ];
    custom = [ /* custom node packages */ ];
  };
  
  server = {
    host = "127.0.0.1";
    port = 8188;
    cors = false;
  };
};
```

### Home Manager Integration
```nix
programs.comfyui = {
  enable = true;
  
  workspace = {
    directory = "~/comfyui-workspace";
    workflows = "~/comfyui-workflows";
  };
  
  models = {
    symlinks = {
      checkpoints = "~/ai-models/checkpoints";
      loras = "~/ai-models/loras";
      controlnet = "~/ai-models/controlnet";
    };
  };
  
  development = {
    enable = true;
    customNodes = [ /* development node packages */ ];
  };
};
```

## Performance Optimization

### IPEX-Specific Optimizations
- Model compilation with Intel XPU backend
- Memory layout optimization
- Kernel fusion for common operations
- Quantization support (INT8, BF16)

### Benchmarking Framework
```nix
comfyui-benchmarks = {
  workflows = [
    "txt2img-basic"
    "img2img-controlnet"
    "upscaling-4x"
    "animation-interpolation"
  ];
  
  metrics = [
    "inference-time"
    "memory-usage"
    "power-consumption"
    "quality-metrics"
  ];
};
```

## Testing Strategy

### Functional Tests
1. **Basic Workflow Tests**: Standard txt2img, img2img
2. **Advanced Workflow Tests**: ControlNet, inpainting, outpainting
3. **Custom Node Tests**: Verify node compatibility
4. **API Tests**: REST API functionality

### Performance Tests
1. **Inference Speed**: Compare with CPU/CUDA baselines
2. **Memory Efficiency**: XPU memory utilization
3. **Batch Processing**: Multi-image workflows
4. **Model Loading**: Optimization effectiveness

### Integration Tests
1. **Ollama + ComfyUI**: Combined workflows
2. **Model Sharing**: Shared model cache
3. **Resource Management**: Concurrent usage

## Documentation and Examples

### User Documentation
- Installation guide
- Configuration examples
- Workflow tutorials
- Troubleshooting guide

### Developer Documentation
- Custom node development
- IPEX optimization guide
- Performance tuning
- API reference

### Example Workflows
- Basic image generation
- ControlNet workflows
- Video processing
- Batch operations

## Deliverables
1. ComfyUI-IPEX package implementation
2. Essential patches for Intel XPU support
3. NixOS and Home Manager modules
4. Custom node compatibility layer
5. Performance benchmarking suite
6. Comprehensive documentation
7. Example workflows and configurations

## Git Workflow
- **Working Branch**: `main`
- **Completion Tag**: `phase3-complete`
- **Commit Message Format**: `phase3: <description>`

### Phase Completion Criteria
- [ ] ComfyUI package building successfully
- [ ] Intel XPU device support working
- [ ] Basic workflows operational
- [ ] Custom node compatibility implemented
- [ ] Performance benchmarks established
- [ ] Integration with Ollama tested
- [ ] All deliverables committed and tagged

### Git Commands for Phase 3
```bash
# Regular commits during development
git add .
git commit -m "phase3: implement comfyui-ipex package"
git commit -m "phase3: add xpu device support patches"
git commit -m "phase3: create custom node compatibility"

# Phase completion
git add .
git commit -m "phase3: complete comfyui integration with ipex"
git tag phase3-complete
```

## Next Phase Prerequisites
- ComfyUI package building successfully
- Basic XPU functionality working
- Core workflows operational
- Performance baseline established
- Integration with Ollama tested
- Git tag `phase3-complete` created
