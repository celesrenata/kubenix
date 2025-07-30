# Phase 1: Analysis and Extraction

## Objective
Analyze MordragT's IPEX implementation and extract the core components needed for Intel XPU acceleration with Ollama and ComfyUI.

## Key Findings from Repository Analysis

### IPEX Infrastructure Components
1. **Intel Python Scope** (`pkgs/by-scope/intel-python/`)
   - Custom Python environment with Intel-optimized packages
   - IPEX (Intel Extension for PyTorch) package
   - Intel-optimized PyTorch, TorchVision, TorchAudio
   - Triton-XPU for GPU kernel compilation
   - OneCCL bindings for distributed computing

2. **Intel Development Tools** (`pkgs/by-name/intel-*`)
   - Intel MKL (Math Kernel Library)
   - Intel TBB (Threading Building Blocks)
   - Intel DPC++ compiler
   - Intel SYCL runtime
   - Level Zero drivers

3. **Ollama SYCL Integration** (`pkgs/by-name/ollama-sycl/`)
   - Custom Ollama build with SYCL support
   - Intel DPC++ compiler integration
   - Custom llama.cpp with SYCL backend
   - GPU runtime library wrapping

### Critical Dependencies
- **Build Support**: Custom fetchers for Intel packages (`fetchipex`, `fetchtorch`)
- **Overlay Structure**: Scoped package sets for Intel ecosystem
- **Driver Integration**: Level Zero and OpenCL runtime support

## Extraction Strategy

### Core Components to Extract
1. **Intel Python Scope**
   - Complete `intel-python` package set
   - Build support functions
   - Custom Python environment overlay

2. **Intel Base Libraries**
   - MKL, TBB, DPC++, SYCL packages
   - Level Zero drivers
   - OpenCL integration

3. **IPEX-Enabled Applications**
   - Ollama with SYCL support
   - InvokeAI with XPU patches
   - Base infrastructure for ComfyUI integration

### Integration Points
- Flake inputs for upstream dependencies
- Overlay system for package customization
- Module system for configuration management
- Hardware detection and driver setup

## Deliverables
1. Comprehensive dependency map
2. Component extraction plan
3. Integration architecture design
4. Compatibility matrix with target applications

## Git Workflow
- **Working Branch**: `main`
- **Completion Tag**: `phase1-complete`
- **Commit Message Format**: `phase1: <description>`

### Phase Completion Criteria
- [ ] Complete component inventory documented
- [ ] Dependency resolution strategy defined
- [ ] Integration architecture designed
- [ ] Initial package extraction tests passing
- [ ] All deliverables committed and tagged

### Git Commands for Phase 1
```bash
# Regular commits during development
git add .
git commit -m "phase1: analyze intel-python scope structure"

# Phase completion
git add .
git commit -m "phase1: complete analysis and extraction planning"
git tag phase1-complete
```

## Next Phase Prerequisites
- Complete component inventory
- Dependency resolution strategy
- Flake input structure design
- Initial package extraction tests
- Git tag `phase1-complete` created
