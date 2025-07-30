# IPEX Integration Project

This project integrates MordragT's Intel IPEX work into a clean flake interface for running Ollama and ComfyUI with Intel XPU acceleration.

## Project Structure

```
.
├── flake.nix                 # Main flake configuration
├── ipex-context/            # Planning and context documents
├── overlays/                # Package overlays
├── modules/                 # NixOS and Home Manager modules
├── packages/                # Custom package definitions
├── examples/                # Usage examples
└── docs/                    # Documentation
```

## Development Phases

This project follows a 4-phase development approach with git commits marking each phase completion:

### Phase 1: Analysis and Extraction
- **Branch**: `main` 
- **Commit**: `phase1-complete`
- **Focus**: Component analysis and extraction strategy
- **Duration**: Weeks 1-2

### Phase 2: Flake Architecture Design  
- **Branch**: `main`
- **Commit**: `phase2-complete`
- **Focus**: Clean flake interface and module system
- **Duration**: Weeks 3-4

### Phase 3: ComfyUI Integration
- **Branch**: `main` 
- **Commit**: `phase3-complete`
- **Focus**: ComfyUI with Intel IPEX support
- **Duration**: Weeks 5-7

### Phase 4: Production Deployment
- **Branch**: `main`
- **Commit**: `phase4-complete` 
- **Focus**: Production readiness and sustainability
- **Duration**: Weeks 8-10

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

## Quick Start

```bash
# Clone and enter directory
git clone <this-repo>
cd <repo-name>

# Check current phase
git log --oneline -1

# Build and test (once implemented)
nix build
nix flake check
```

## Documentation

See `ipex-context/` for detailed planning documents:
- `project-overview.md` - Complete project summary
- `phase1-analysis-and-extraction.md` - Component analysis plan
- `phase2-flake-architecture.md` - Flake design specification  
- `phase3-comfyui-integration.md` - ComfyUI integration plan
- `phase4-production-deployment.md` - Production deployment plan

## Contributing

This is a structured development project. Please follow the phase-based approach and ensure each phase is complete before moving to the next.

## License

[Add your license here]
