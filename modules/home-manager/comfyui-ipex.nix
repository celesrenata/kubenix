{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.programs.comfyui-ipex;
in
{
  options.programs.comfyui-ipex = {
    enable = mkEnableOption "ComfyUI with Intel IPEX development environment";
    
    workspace = {
      directory = mkOption {
        type = types.str;
        default = "~/comfyui-workspace";
        description = "ComfyUI workspace directory";
      };
      
      workflows = mkOption {
        type = types.str;
        default = "~/comfyui-workflows";
        description = "Directory for ComfyUI workflows";
      };
    };
    
    models = {
      symlinks = mkOption {
        type = types.attrsOf types.str;
        default = {
          checkpoints = "~/ai-models/checkpoints";
          loras = "~/ai-models/loras";
          controlnet = "~/ai-models/controlnet";
          vae = "~/ai-models/vae";
          upscale_models = "~/ai-models/upscale";
          embeddings = "~/ai-models/embeddings";
        };
        description = "Symlinks to model directories";
        example = {
          checkpoints = "~/models/stable-diffusion";
          loras = "~/models/loras";
        };
      };
    };
    
    development = {
      enable = mkEnableOption "ComfyUI development tools";
      
      customNodes = mkOption {
        type = types.listOf types.package;
        default = [ ];
        description = "Custom node packages for development";
      };
      
      vscode = mkEnableOption "VS Code with ComfyUI extensions";
      
      jupyter = mkEnableOption "Jupyter notebook with ComfyUI kernel";
    };
    
    aliases = mkOption {
      type = types.attrsOf types.str;
      default = {
        comfyui = "comfyui-ipex --listen 127.0.0.1 --port 8188";
        comfyui-dev = "comfyui-ipex --listen 0.0.0.0 --port 8188 --enable-cors-header";
        comfyui-cpu = "comfyui-ipex --cpu --listen 127.0.0.1 --port 8188";
        comfyui-info = "python3 -c 'import torch; import intel_extension_for_pytorch as ipex; print(f\"PyTorch: {torch.__version__}\"); print(f\"IPEX: {ipex.__version__}\"); print(f\"XPU available: {torch.xpu.is_available() if hasattr(torch, \"xpu\") else False}\")'";
      };
      description = "Shell aliases for ComfyUI commands";
    };
  };
  
  config = mkIf cfg.enable {
    # Ensure IPEX development environment is available
    programs.ipex.enable = mkDefault true;
    
    # Add ComfyUI to user packages
    home.packages = with pkgs; [
      comfyui-ipex
    ] ++ optionals cfg.development.enable [
      # Development tools
      python3Packages.ipython
      python3Packages.jupyter
      python3Packages.matplotlib
      python3Packages.opencv4
    ] ++ cfg.development.customNodes;
    
    # Create workspace directories
    home.file."${cfg.workspace.directory}/.keep".text = "";
    home.file."${cfg.workspace.workflows}/.keep".text = "";
    
    # Create model directory symlinks
    home.file = mapAttrs' (name: path: 
      nameValuePair "${cfg.workspace.directory}/models/${name}" {
        source = config.lib.file.mkOutOfStoreSymlink path;
      }
    ) cfg.models.symlinks;
    
    # Shell aliases
    programs.bash.shellAliases = cfg.aliases;
    programs.zsh.shellAliases = cfg.aliases;
    
    # Environment variables
    home.sessionVariables = {
      # ComfyUI configuration
      COMFYUI_WORKSPACE = cfg.workspace.directory;
      COMFYUI_WORKFLOWS = cfg.workspace.workflows;
      
      # Intel GPU environment
      ZES_ENABLE_SYSMAN = "1";
      ONEAPI_DEVICE_SELECTOR = "opencl:*";
    };
    
    # VS Code configuration for ComfyUI development
    programs.vscode = mkIf cfg.development.vscode {
      enable = true;
      extensions = with pkgs.vscode-extensions; [
        ms-python.python
        ms-python.debugpy
        ms-toolsai.jupyter
        # JSON support for ComfyUI workflows
        ms-vscode.json
      ];
      
      userSettings = {
        "python.defaultInterpreterPath" = "${pkgs.intel-xpu.python}/bin/python";
        "python.terminal.activateEnvironment" = false;
        
        # ComfyUI specific settings
        "files.associations" = {
          "*.json" = "json";
          "*.workflow" = "json";
        };
        
        # Jupyter settings
        "jupyter.kernels.filter" = [
          {
            "path" = "${pkgs.intel-xpu.python}/bin/python";
            "type" = "pythonEnvironment";
          }
        ];
      };
      
      keybindings = [
        {
          key = "ctrl+shift+c";
          command = "workbench.action.terminal.sendSequence";
          args = {
            text = "comfyui-dev\n";
          };
          when = "terminalFocus";
        }
      ];
    };
    
    # Jupyter configuration for ComfyUI development
    programs.jupyter = mkIf cfg.development.jupyter {
      enable = true;
      kernels = {
        comfyui-ipex = {
          displayName = "ComfyUI (Intel IPEX)";
          language = "python";
          argv = [
            "${pkgs.intel-xpu.python}/bin/python"
            "-m"
            "ipykernel_launcher"
            "-f"
            "{connection_file}"
          ];
          env = {
            ZES_ENABLE_SYSMAN = "1";
            ONEAPI_DEVICE_SELECTOR = "opencl:*";
            COMFYUI_WORKSPACE = cfg.workspace.directory;
          };
        };
      };
    };
    
    # Create example workflow files
    home.file."${cfg.workspace.workflows}/basic-txt2img.json" = {
      text = builtins.toJSON {
        "1" = {
          "inputs" = {
            "ckpt_name" = "sd_xl_base_1.0.safetensors";
          };
          "class_type" = "CheckpointLoaderSimple";
          "_meta" = {
            "title" = "Load Checkpoint";
          };
        };
        "2" = {
          "inputs" = {
            "text" = "a beautiful landscape with mountains and a lake";
            "clip" = [ "1" 1 ];
          };
          "class_type" = "CLIPTextEncode";
          "_meta" = {
            "title" = "CLIP Text Encode (Prompt)";
          };
        };
        "3" = {
          "inputs" = {
            "text" = "";
            "clip" = [ "1" 1 ];
          };
          "class_type" = "CLIPTextEncode";
          "_meta" = {
            "title" = "CLIP Text Encode (Negative)";
          };
        };
        "4" = {
          "inputs" = {
            "width" = 1024;
            "height" = 1024;
            "batch_size" = 1;
          };
          "class_type" = "EmptyLatentImage";
          "_meta" = {
            "title" = "Empty Latent Image";
          };
        };
        "5" = {
          "inputs" = {
            "seed" = 42;
            "steps" = 20;
            "cfg" = 7.0;
            "sampler_name" = "euler";
            "scheduler" = "normal";
            "denoise" = 1.0;
            "model" = [ "1" 0 ];
            "positive" = [ "2" 0 ];
            "negative" = [ "3" 0 ];
            "latent_image" = [ "4" 0 ];
          };
          "class_type" = "KSampler";
          "_meta" = {
            "title" = "KSampler";
          };
        };
        "6" = {
          "inputs" = {
            "samples" = [ "5" 0 ];
            "vae" = [ "1" 2 ];
          };
          "class_type" = "VAEDecode";
          "_meta" = {
            "title" = "VAE Decode";
          };
        };
        "7" = {
          "inputs" = {
            "filename_prefix" = "ComfyUI-IPEX";
            "images" = [ "6" 0 ];
          };
          "class_type" = "SaveImage";
          "_meta" = {
            "title" = "Save Image";
          };
        };
      };
    };
    
    # Create development scripts
    home.file."${cfg.workspace.directory}/scripts/benchmark.py" = {
      text = ''
        #!/usr/bin/env python3
        """
        ComfyUI Intel IPEX Benchmark Script
        """
        import time
        import torch
        import intel_extension_for_pytorch as ipex
        import psutil
        import json
        from pathlib import Path
        
        def benchmark_inference():
            """Run basic inference benchmark"""
            print("🚀 ComfyUI Intel IPEX Benchmark")
            print("=" * 40)
            
            # System info
            print(f"PyTorch version: {torch.__version__}")
            print(f"IPEX version: {ipex.__version__}")
            
            if hasattr(torch, 'xpu') and torch.xpu.is_available():
                print(f"Intel XPU available: Yes")
                print(f"XPU device count: {torch.xpu.device_count()}")
                device = torch.device('xpu')
            else:
                print(f"Intel XPU available: No, using CPU")
                device = torch.device('cpu')
            
            print(f"Using device: {device}")
            print(f"Available memory: {psutil.virtual_memory().available / 1024**3:.1f} GB")
            print()
            
            # Simple tensor operations benchmark
            print("Running tensor operations benchmark...")
            sizes = [512, 1024, 2048]
            results = {}
            
            for size in sizes:
                print(f"  Testing {size}x{size} tensors...")
                
                # Create test tensors
                a = torch.randn(size, size, device=device, dtype=torch.float16)
                b = torch.randn(size, size, device=device, dtype=torch.float16)
                
                # Warmup
                for _ in range(5):
                    _ = torch.matmul(a, b)
                
                # Benchmark
                start_time = time.time()
                for _ in range(10):
                    result = torch.matmul(a, b)
                    if device.type == 'xpu':
                        torch.xpu.synchronize()
                end_time = time.time()
                
                avg_time = (end_time - start_time) / 10
                results[f"{size}x{size}"] = {
                    "avg_time_ms": avg_time * 1000,
                    "ops_per_sec": 1 / avg_time
                }
                
                print(f"    Average time: {avg_time * 1000:.2f} ms")
                print(f"    Operations/sec: {1/avg_time:.2f}")
            
            # Save results
            results_file = Path("benchmark_results.json")
            with open(results_file, 'w') as f:
                json.dump(results, f, indent=2)
            
            print(f"\n✅ Benchmark complete! Results saved to {results_file}")
            return results
        
        if __name__ == "__main__":
            benchmark_inference()
      '';
      executable = true;
    };
    
    # Create README for workspace
    home.file."${cfg.workspace.directory}/README.md" = {
      text = ''
        # ComfyUI Intel IPEX Workspace
        
        This workspace is configured for ComfyUI development with Intel IPEX acceleration.
        
        ## Quick Start
        
        ```bash
        # Start ComfyUI with Intel XPU acceleration
        comfyui
        
        # Start ComfyUI in development mode (accessible from network)
        comfyui-dev
        
        # Start ComfyUI with CPU only
        comfyui-cpu
        
        # Check IPEX installation
        comfyui-info
        ```
        
        ## Directory Structure
        
        - `models/` - Symlinked model directories
        - `workflows/` - ComfyUI workflow files
        - `scripts/` - Development and benchmark scripts
        
        ## Development
        
        - VS Code is configured with Python and Jupyter extensions
        - Jupyter kernels available for ComfyUI development
        - Custom nodes can be installed in the development environment
        
        ## Benchmarking
        
        Run the benchmark script to test Intel XPU performance:
        
        ```bash
        cd scripts
        python benchmark.py
        ```
        
        ## Model Management
        
        Models are organized in the following directories:
        ${concatStringsSep "\n" (mapAttrsToList (name: path: "- `models/${name}/` -> `${path}`") cfg.models.symlinks)}
        
        ## Troubleshooting
        
        1. **Intel GPU not detected**: Check `comfyui-info` output
        2. **Performance issues**: Try different optimization levels
        3. **Memory errors**: Reduce batch size or use CPU fallback
        
        For more help, check the ComfyUI documentation and Intel IPEX guides.
      '';
    };
  };
}
