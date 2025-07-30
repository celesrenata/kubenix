# Production IPEX Deployment Configuration
# This configuration provides a production-ready setup for Intel IPEX
# with Ollama and ComfyUI services, monitoring, and security hardening.

{ config, lib, pkgs, ... }:

{
  imports = [
    # Hardware configuration (customize for your system)
    ./hardware-configuration.nix
    
    # IPEX modules
    ../../modules/nixos/ipex.nix
    ../../modules/nixos/ollama-ipex.nix
    ../../modules/nixos/comfyui-ipex.nix
  ];

  # System Configuration
  system.stateVersion = "24.05";
  networking.hostName = "ipex-production";
  
  # Boot Configuration
  boot = {
    loader = {
      systemd-boot.enable = true;
      efi.canTouchEfiVariables = true;
    };
    
    # Kernel parameters for Intel GPU
    kernelParams = [
      "i915.enable_guc=2"  # Enable GuC and HuC firmware
      "i915.enable_fbc=1"  # Enable framebuffer compression
    ];
    
    # Load Intel GPU modules early
    initrd.kernelModules = [ "i915" ];
  };

  # Intel IPEX Configuration
  services.ipex = {
    enable = true;
    autoDetectHardware = true;
    devices = [ "gpu" "cpu" ];
    optimization = "performance";
  };

  # Ollama Production Configuration
  services.ollama-ipex = {
    enable = true;
    host = "0.0.0.0";  # Allow network access
    port = 11434;
    acceleration = "auto";
    
    # Production model storage
    models = "/var/lib/ollama/models";
  };

  # ComfyUI Production Configuration
  services.comfyui-ipex = {
    enable = true;
    host = "0.0.0.0";  # Allow network access
    port = 8188;
    acceleration = "auto";
    
    # Production settings
    models = {
      path = "/var/lib/comfyui/models";
      autoDownload = false;  # Manual model management in production
      cache = {
        enable = true;
        size = "20GB";
      };
    };
    
    # Performance optimization
    optimization = {
      level = "O2";  # Higher optimization for production
      precision = "fp16";  # Memory efficient
      jitCompile = true;
    };
    
    # Enable essential custom nodes
    nodes.enable = [ "controlnet-aux" "upscaling" ];
    
    # Server configuration
    server = {
      cors = false;  # Disable CORS in production
      maxUploadSize = "500M";  # Large image support
    };
  };

  # Monitoring and Logging
  services.prometheus = {
    enable = true;
    port = 9090;
    
    # Scrape configurations
    scrapeConfigs = [
      {
        job_name = "node";
        static_configs = [{
          targets = [ "localhost:9100" ];
        }];
      }
      {
        job_name = "ollama";
        static_configs = [{
          targets = [ "localhost:11434" ];
        }];
        metrics_path = "/metrics";
      }
      {
        job_name = "comfyui";
        static_configs = [{
          targets = [ "localhost:8188" ];
        }];
        metrics_path = "/metrics";
      }
    ];
  };

  services.prometheus.exporters = {
    node = {
      enable = true;
      enabledCollectors = [
        "systemd"
        "processes"
        "cpu"
        "meminfo"
        "diskstats"
        "filesystem"
        "netdev"
        "loadavg"
      ];
    };
  };

  services.grafana = {
    enable = true;
    settings = {
      server = {
        http_addr = "0.0.0.0";
        http_port = 3000;
        domain = "localhost";
      };
      
      security = {
        admin_user = "admin";
        admin_password = "$__file{/etc/grafana/admin-password}";
      };
    };
    
    provision = {
      enable = true;
      datasources.settings.datasources = [{
        name = "Prometheus";
        type = "prometheus";
        url = "http://localhost:9090";
        isDefault = true;
      }];
    };
  };

  # Reverse Proxy with SSL
  services.nginx = {
    enable = true;
    
    # Security headers
    appendHttpConfig = ''
      # Security headers
      add_header X-Frame-Options DENY;
      add_header X-Content-Type-Options nosniff;
      add_header X-XSS-Protection "1; mode=block";
      add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
      
      # Rate limiting
      limit_req_zone $binary_remote_addr zone=api:10m rate=10r/s;
      limit_req_zone $binary_remote_addr zone=upload:10m rate=1r/s;
    '';
    
    virtualHosts = {
      "ipex.local" = {
        default = true;
        
        locations = {
          "/" = {
            return = "301 https://$server_name$request_uri";
          };
        };
      };
      
      "ipex.local:443" = {
        enableACME = false;  # Configure SSL certificates as needed
        forceSSL = false;    # Enable when SSL is configured
        
        locations = {
          "/" = {
            root = pkgs.writeTextDir "index.html" ''
              <!DOCTYPE html>
              <html>
              <head>
                <title>IPEX Production Services</title>
                <style>
                  body { font-family: Arial, sans-serif; margin: 40px; }
                  .service { margin: 20px 0; padding: 20px; border: 1px solid #ddd; border-radius: 5px; }
                  .service h3 { margin-top: 0; color: #333; }
                  .service a { color: #0066cc; text-decoration: none; }
                  .service a:hover { text-decoration: underline; }
                </style>
              </head>
              <body>
                <h1>🚀 IPEX Production Services</h1>
                <p>Intel IPEX acceleration platform with AI/ML services</p>
                
                <div class="service">
                  <h3>🤖 Ollama (LLM Service)</h3>
                  <p>Large Language Model inference with Intel XPU acceleration</p>
                  <a href="/ollama/">Access Ollama API</a>
                </div>
                
                <div class="service">
                  <h3>🎨 ComfyUI (Image Generation)</h3>
                  <p>Stable Diffusion and image processing with Intel IPEX</p>
                  <a href="/comfyui/">Access ComfyUI Interface</a>
                </div>
                
                <div class="service">
                  <h3>📊 Monitoring (Grafana)</h3>
                  <p>System performance and service monitoring</p>
                  <a href="/grafana/">Access Grafana Dashboard</a>
                </div>
                
                <div class="service">
                  <h3>📈 Metrics (Prometheus)</h3>
                  <p>Raw metrics and monitoring data</p>
                  <a href="/prometheus/">Access Prometheus</a>
                </div>
              </body>
              </html>
            '';
          };
          
          "/ollama/" = {
            proxyPass = "http://127.0.0.1:11434/";
            extraConfig = ''
              limit_req zone=api burst=20 nodelay;
              proxy_buffering off;
              proxy_request_buffering off;
              proxy_read_timeout 300s;
              proxy_connect_timeout 10s;
            '';
          };
          
          "/comfyui/" = {
            proxyPass = "http://127.0.0.1:8188/";
            extraConfig = ''
              limit_req zone=upload burst=5 nodelay;
              client_max_body_size 500M;
              proxy_read_timeout 600s;
              proxy_connect_timeout 10s;
              proxy_send_timeout 600s;
            '';
          };
          
          "/grafana/" = {
            proxyPass = "http://127.0.0.1:3000/";
            extraConfig = ''
              proxy_set_header Host $host;
              proxy_set_header X-Real-IP $remote_addr;
              proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
              proxy_set_header X-Forwarded-Proto $scheme;
            '';
          };
          
          "/prometheus/" = {
            proxyPass = "http://127.0.0.1:9090/";
            extraConfig = ''
              auth_basic "Prometheus";
              auth_basic_user_file /etc/nginx/prometheus.htpasswd;
            '';
          };
        };
      };
    };
  };

  # Firewall Configuration
  networking.firewall = {
    enable = true;
    allowedTCPPorts = [ 
      22    # SSH
      80    # HTTP
      443   # HTTPS
      3000  # Grafana (if direct access needed)
    ];
    
    # Rate limiting
    extraCommands = ''
      # Limit SSH connections
      iptables -A INPUT -p tcp --dport 22 -m conntrack --ctstate NEW -m recent --set
      iptables -A INPUT -p tcp --dport 22 -m conntrack --ctstate NEW -m recent --update --seconds 60 --hitcount 4 -j DROP
      
      # Limit HTTP connections
      iptables -A INPUT -p tcp --dport 80 -m conntrack --ctstate NEW -m recent --set
      iptables -A INPUT -p tcp --dport 80 -m conntrack --ctstate NEW -m recent --update --seconds 1 --hitcount 20 -j DROP
    '';
  };

  # System Security
  security = {
    # Sudo configuration
    sudo = {
      enable = true;
      wheelNeedsPassword = true;
    };
    
    # Fail2ban for intrusion prevention
    fail2ban = {
      enable = true;
      maxretry = 3;
      bantime = "1h";
      
      jails = {
        ssh = {
          enabled = true;
          filter = "sshd";
          action = "iptables[name=ssh, port=ssh, protocol=tcp]";
        };
        
        nginx-http-auth = {
          enabled = true;
          filter = "nginx-http-auth";
          action = "iptables[name=nginx-http-auth, port=http, protocol=tcp]";
        };
      };
    };
  };

  # User Management
  users = {
    mutableUsers = false;  # Declarative user management
    
    users = {
      # System administrator
      admin = {
        isNormalUser = true;
        extraGroups = [ "wheel" "systemd-journal" ];
        openssh.authorizedKeys.keys = [
          # Add your SSH public keys here
          # "ssh-rsa AAAAB3NzaC1yc2E... admin@example.com"
        ];
      };
      
      # Service monitoring user
      monitoring = {
        isSystemUser = true;
        group = "monitoring";
        extraGroups = [ "systemd-journal" ];
      };
    };
    
    groups.monitoring = {};
  };

  # SSH Configuration
  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      PermitRootLogin = "no";
      X11Forwarding = false;
      MaxAuthTries = 3;
      ClientAliveInterval = 300;
      ClientAliveCountMax = 2;
    };
  };

  # Automatic Updates and Maintenance
  system.autoUpgrade = {
    enable = true;
    flake = "github:yourusername/ipex-flake";  # Update with your repository
    flags = [
      "--update-input" "nixpkgs"
      "--update-input" "mordrag-nixos"
      "--no-write-lock-file"
    ];
    dates = "04:00";  # Daily at 4 AM
    randomizedDelaySec = "45min";
    allowReboot = false;  # Manual reboot for production
  };

  # Log Management
  services.logrotate = {
    enable = true;
    settings = {
      "/var/log/nginx/*.log" = {
        frequency = "daily";
        rotate = 30;
        compress = true;
        delaycompress = true;
        missingok = true;
        notifempty = true;
        create = "644 nginx nginx";
        postrotate = "systemctl reload nginx";
      };
      
      "/var/log/ollama/*.log" = {
        frequency = "weekly";
        rotate = 4;
        compress = true;
        missingok = true;
        notifempty = true;
        create = "644 ollama ollama";
      };
      
      "/var/log/comfyui/*.log" = {
        frequency = "weekly";
        rotate = 4;
        compress = true;
        missingok = true;
        notifempty = true;
        create = "644 comfyui comfyui";
      };
    };
  };

  # System Packages
  environment.systemPackages = with pkgs; [
    # System administration
    htop
    iotop
    nethogs
    tcpdump
    strace
    
    # Intel GPU tools
    intel-gpu-tools
    libva-utils
    
    # IPEX tools
    ipex-benchmarks
    
    # Monitoring
    prometheus-node-exporter
    
    # Network tools
    curl
    wget
    nmap
    
    # Text editors
    vim
    nano
  ];

  # Environment Variables
  environment.variables = {
    # Intel GPU optimization
    INTEL_GPU_OPTIMIZATION = "1";
    
    # IPEX configuration
    IPEX_OPTIMIZATION_LEVEL = "O2";
    IPEX_PRECISION = "fp16";
  };

  # Systemd Journal Configuration
  services.journald.settings = {
    SystemMaxUse = "1G";
    SystemMaxFileSize = "100M";
    SystemMaxFiles = 10;
    MaxRetentionSec = "1month";
  };

  # Time and Locale
  time.timeZone = "UTC";
  i18n.defaultLocale = "en_US.UTF-8";

  # Hardware Optimization
  hardware = {
    # Enable Intel GPU
    graphics = {
      enable = true;
      extraPackages = with pkgs; [
        intel-media-driver
        intel-compute-runtime
        level-zero
      ];
    };
    
    # CPU microcode updates
    cpu.intel.updateMicrocode = true;
  };

  # Performance Tuning
  boot.kernel.sysctl = {
    # Network performance
    "net.core.rmem_max" = 134217728;
    "net.core.wmem_max" = 134217728;
    "net.ipv4.tcp_rmem" = "4096 87380 134217728";
    "net.ipv4.tcp_wmem" = "4096 65536 134217728";
    
    # Memory management
    "vm.swappiness" = 10;
    "vm.dirty_ratio" = 15;
    "vm.dirty_background_ratio" = 5;
    
    # File system
    "fs.file-max" = 2097152;
  };
}
