# Getting Started with IPEX Integration

Welcome to the Intel IPEX Integration project! This guide will help you get started with running Ollama and ComfyUI with Intel XPU acceleration.

## Prerequisites

### Hardware Requirements
- **Intel GPU**: Arc A-series, Iris Xe, or newer Intel integrated graphics
- **CPU**: Intel processor with integrated graphics (minimum)
- **Memory**: 16GB+ RAM recommended for AI workloads
- **Storage**: NVMe SSD recommended for model storage (100GB+ free space)

### Software Requirements
- **NixOS**: Version 24.05 or newer
- **Nix Flakes**: Enabled in your configuration
- **Git**: For cloning the repository

## Quick Start

### 1. Clone the Repository

```bash
git clone https://github.com/yourusername/ipex-flake.git
cd ipex-flake
```

### 2. Basic Configuration

Add the IPEX flake to your NixOS configuration:

```nix
# /etc/nixos/flake.nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    ipex-flake.url = "github:yourusername/ipex-flake";
  };

  outputs = { nixpkgs, ipex-flake, ... }: {
    nixosConfigurations.your-hostname = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        ./configuration.nix
        ipex-flake.nixosModules.ipex
        ipex-flake.nixosModules.ollama-ipex
        ipex-flake.nixosModules.comfyui-ipex
      ];
    };
  };
}
```

### 3. Enable IPEX Services

Add to your `/etc/nixos/configuration.nix`:

```nix
{
  # Enable Intel IPEX support
  services.ipex = {
    enable = true;
    autoDetectHardware = true;
    devices = [ "gpu" "cpu" ];
    optimization = "balanced";
  };

  # Enable Ollama with IPEX
  services.ollama-ipex = {
    enable = true;
    host = "127.0.0.1";  # Local access only
    port = 11434;
    acceleration = "auto";
  };

  # Enable ComfyUI with IPEX
  services.comfyui-ipex = {
    enable = true;
    host = "127.0.0.1";  # Local access only
    port = 8188;
    acceleration = "auto";
    
    models = {
      path = "/var/lib/comfyui/models";
      autoDownload = true;  # Download basic models
    };
  };
}
```

### 4. Rebuild Your System

```bash
sudo nixos-rebuild switch
```

### 5. Verify Installation

Check that services are running:

```bash
# Check service status
systemctl status ollama-ipex
systemctl status comfyui-ipex

# Test Ollama API
curl http://localhost:11434/api/tags

# Test ComfyUI interface
curl http://localhost:8188/system_stats
```

## Using the Services

### Ollama (Large Language Models)

#### Web Interface
Open your browser and go to: `http://localhost:11434`

#### Command Line
```bash
# List available models
curl http://localhost:11434/api/tags

# Pull a model
curl -X POST http://localhost:11434/api/pull -d '{"name": "llama2"}'

# Generate text
curl -X POST http://localhost:11434/api/generate -d '{
  "model": "llama2",
  "prompt": "Why is the sky blue?",
  "stream": false
}'
```

### ComfyUI (Image Generation)

#### Web Interface
Open your browser and go to: `http://localhost:8188`

#### Basic Workflow
1. **Load a Model**: Drag a "Load Checkpoint" node
2. **Add Prompts**: Use "CLIP Text Encode" nodes for positive/negative prompts
3. **Generate**: Connect to "KSampler" and "VAE Decode" nodes
4. **Save**: Use "Save Image" node for output

#### Example Workflow
```json
{
  "1": {
    "inputs": {"ckpt_name": "sd_xl_base_1.0.safetensors"},
    "class_type": "CheckpointLoaderSimple"
  },
  "2": {
    "inputs": {
      "text": "a beautiful landscape with mountains",
      "clip": ["1", 1]
    },
    "class_type": "CLIPTextEncode"
  }
}
```

## Performance Optimization

### Intel GPU Optimization

Check GPU status:
```bash
# Monitor GPU usage
intel_gpu_top

# Check GPU information
lspci | grep -i intel
```

### IPEX Configuration

Adjust optimization levels in your configuration:

```nix
services.comfyui-ipex = {
  optimization = {
    level = "O2";        # O0, O1, O2, O3 (higher = more optimized)
    precision = "fp16";  # fp32, fp16, bf16, int8
    jitCompile = true;   # Enable JIT compilation
  };
};
```

### Memory Management

For systems with limited memory:

```nix
services.comfyui-ipex = {
  models.cache = {
    enable = true;
    size = "8GB";  # Adjust based on available memory
  };
};
```

## Troubleshooting

### Intel GPU Not Detected

1. **Check Hardware Support**:
   ```bash
   lspci | grep -i intel
   ls /dev/dri/
   ```

2. **Verify Drivers**:
   ```bash
   intel_gpu_top -l 1
   ```

3. **Check Environment Variables**:
   ```bash
   echo $ZES_ENABLE_SYSMAN
   echo $ONEAPI_DEVICE_SELECTOR
   ```

### Service Not Starting

1. **Check Service Logs**:
   ```bash
   journalctl -u ollama-ipex -f
   journalctl -u comfyui-ipex -f
   ```

2. **Verify Configuration**:
   ```bash
   nixos-rebuild dry-run
   ```

3. **Test IPEX Installation**:
   ```bash
   python3 -c "import intel_extension_for_pytorch as ipex; print(f'IPEX {ipex.__version__} ready')"
   ```

### Performance Issues

1. **Run Benchmarks**:
   ```bash
   nix run .#ipex-benchmarks
   ```

2. **Monitor Resources**:
   ```bash
   htop
   intel_gpu_top
   ```

3. **Adjust Optimization**:
   - Try different optimization levels (O0-O3)
   - Experiment with precision settings (fp32/fp16)
   - Enable/disable JIT compilation

### Common Issues

#### "IPEX not available"
- Ensure Intel GPU drivers are installed
- Check that IPEX service is enabled
- Verify environment variables are set

#### "Out of memory"
- Reduce batch sizes
- Lower precision (fp16 instead of fp32)
- Enable model caching
- Add more system RAM

#### "Slow inference"
- Enable Intel GPU acceleration
- Increase optimization level
- Use appropriate precision
- Check GPU utilization with `intel_gpu_top`

## Development Environment

### Home Manager Setup

Add to your Home Manager configuration:

```nix
{
  programs.ipex = {
    enable = true;
    development = {
      enable = true;
      vscode = true;
      jupyter = true;
    };
  };

  programs.comfyui-ipex = {
    enable = true;
    development.enable = true;
    workspace.directory = "~/comfyui-workspace";
  };
}
```

### Development Commands

```bash
# Start ComfyUI in development mode
comfyui-ipex --listen 0.0.0.0 --enable-cors-header

# Run performance benchmarks
ipex-benchmark --quick

# Check IPEX status
comfyui-info
```

## Next Steps

- **Explore Models**: Download and try different AI models
- **Custom Workflows**: Create complex image generation workflows
- **Performance Tuning**: Optimize for your specific hardware
- **Monitoring**: Set up production monitoring (see deployment guide)
- **Custom Nodes**: Install additional ComfyUI custom nodes

## Getting Help

- **Documentation**: Check the `docs/` directory for detailed guides
- **Issues**: Report problems on the GitHub repository
- **Community**: Join discussions and share experiences
- **Examples**: See `examples/` directory for configuration templates

## Security Considerations

For production deployments:

1. **Change Default Ports**: Use non-standard ports
2. **Enable Authentication**: Set up proper access controls
3. **Use HTTPS**: Configure SSL certificates
4. **Firewall Rules**: Restrict network access
5. **Regular Updates**: Keep system and packages updated

See the [Production Deployment Guide](../deployment/production-setup.md) for detailed security configuration.
