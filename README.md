# Intel XPU Integration Project

This project integrates Intel GPU acceleration into a clean flake interface for running Ollama and ComfyUI with Intel XPU support using **mainline PyTorch** instead of the deprecated IPEX extension.

## Key Changes (November 2025)

🚀 **Updated to use mainline PyTorch instead of Intel IPEX extension!**

- **PyTorch 2.9.0+**: Native Intel XPU support is now built into mainline PyTorch
- **No separate IPEX extension needed**: Intel optimizations are included by default
- **Simplified architecture**: Uses nixpkgs PyTorch with Intel MKL libraries
- **Better sustainability**: Following Intel's deprecation of standalone IPEX

## Project Structure

```
.
├── flake.nix                 # Main flake configuration (updated for mainline PyTorch)
├── ipex-context/            # Planning and context documents
├── overlays/                # Package overlays
├── modules/                 # NixOS and Home Manager modules
├── packages/                # Custom package definitions (simplified)
├── examples/                # Usage examples
└── docs/                    # Documentation
```

## Available Packages

- **comfyui-xpu**: ComfyUI with Intel-optimized PyTorch and MKL libraries
- **ollama-xpu**: Ollama with Intel GPU acceleration
- **ipex-benchmarks**: Performance testing suite

## Quick Start

```bash
# Clone and enter directory
git clone <this-repo>
cd <repo-name>

# Build with mainline PyTorch approach
nix build .#comfyui-xpu
nix build .#ollama-xpu

# Test the packages
nix run .#comfyui-xpu -- --help-gpu
```

## Development Phases

This project follows a 4-phase development approach with git commits marking each phase completion:

### Phase 1: Analysis and Extraction ✅
- **Branch**: `main` 
- **Commit**: `phase1-complete`
- **Focus**: Component analysis and extraction strategy
- **Duration**: Weeks 1-2

### Phase 2: Flake Architecture Design ✅
- **Branch**: `main`
- **Commit**: `phase2-complete`
- **Focus**: Clean flake interface and module system
- **Duration**: Weeks 3-4

### Phase 3: ComfyUI Integration ✅
- **Branch**: `main` 
- **Commit**: `phase3-complete`
- **Focus**: ComfyUI with Intel XPU support
- **Duration**: Weeks 5-7

### Phase 4: Production Deployment (Updated) 🔄
- **Branch**: `main`
- **Commit**: `phase4-complete` 
- **Focus**: Mainline PyTorch migration and sustainability
- **Duration**: Weeks 8-10

## Migration Notes

**From IPEX Extension → Mainline PyTorch:**
- Removed `ipex-llm` package dependency
- Using `pkgs.python3Packages.torch` with Intel MKL
- Simplified build process and reduced complexity
- Better long-term sustainability following Intel's roadmap

## Git Workflow

Each phase ends with a tagged commit for easy navigation:

```bash
# View all phase commits
git log --oneline --grep="phase.*-complete"

# Return to a specific phase
git checkout phase1-complete  # or phase2-complete, etc.

# Continue from current phase
git checkout main
```

## Documentation

See `ipex-context/` for detailed planning documents:
- `project-overview.md` - Complete project summary
- `phase1-analysis-and-extraction.md` - Component analysis plan
- `phase2-flake-architecture.md` - Flake design specification  
- `phase3-comfyui-integration.md` - ComfyUI integration plan
- `phase4-production-deployment.md` - Production deployment plan (updated for mainline PyTorch)

## Contributing

This is a structured development project. Please follow the phase-based approach and ensure each phase is complete before moving to the next.

## License

[Add your license here]
