{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.programs.ipex;
in
{
  options.programs.ipex = {
    enable = mkEnableOption "Intel IPEX development environment";
    
    pythonPackages = mkOption {
      type = types.listOf types.str;
      default = [ "ipex" "torch" "torchvision" ];
      description = "Additional Python packages to include in IPEX environment";
    };
    
    development = {
      enable = mkEnableOption "IPEX development tools";
      
      vscode = mkEnableOption "VS Code with IPEX extensions";
      
      jupyter = mkEnableOption "Jupyter notebook with IPEX kernel";
    };
    
    aliases = mkOption {
      type = types.attrsOf types.str;
      default = {
        python-ipex = "python3 -c 'import intel_extension_for_pytorch as ipex; print(f\"IPEX {ipex.__version__} ready\")'";
        ipex-info = "python3 -c 'import intel_extension_for_pytorch as ipex; print(ipex.xpu.get_device_properties(0))'";
      };
      description = "Shell aliases for IPEX commands";
    };
  };
  
  config = mkIf cfg.enable {
    # Add IPEX Python environment to user packages
    home.packages = with pkgs; [
      intel-xpu.python
    ] ++ optionals cfg.development.enable [
      # Development tools
      python3Packages.ipython
      python3Packages.jupyter
    ];
    
    # Shell aliases
    programs.bash.shellAliases = cfg.aliases;
    programs.zsh.shellAliases = cfg.aliases;
    
    # Environment variables
    home.sessionVariables = {
      # Intel GPU environment
      ZES_ENABLE_SYSMAN = "1";
      ONEAPI_DEVICE_SELECTOR = "opencl:*";
    };
    
    # VS Code configuration
    programs.vscode = mkIf cfg.development.vscode {
      enable = true;
      extensions = with pkgs.vscode-extensions; [
        ms-python.python
        ms-python.debugpy
      ];
      
      userSettings = {
        "python.defaultInterpreterPath" = "${pkgs.intel-xpu.python}/bin/python";
        "python.terminal.activateEnvironment" = false;
      };
    };
    
    # Jupyter configuration
    programs.jupyter = mkIf cfg.development.jupyter {
      enable = true;
      kernels = {
        ipex = {
          displayName = "Python (IPEX)";
          language = "python";
          argv = [
            "${pkgs.intel-xpu.python}/bin/python"
            "-m"
            "ipykernel_launcher"
            "-f"
            "{connection_file}"
          ];
        };
      };
    };
  };
}
