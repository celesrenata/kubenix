# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ lib, pkgs, pkgs-stable, pkgs-unstable, ... }:
{
  imports =
    [ # Include the results of the hardware scan.
      ./hardware-configuration.nix
    ];

  # Enable Flakes.
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  # Udev rules.
  hardware.uinput.enable = true;

  # Set your time zone.

  services.automatic-timezoned.enable = true;
  location.provider = "geoclue2";
  
  # Create ollama user and group
  users.users.ollama = {
    isSystemUser = true;
    group = "ollama";
    home = "/var/lib/ollama";
    createHome = true;
    extraGroups = [ "render" ];  # Add to render group for Intel GPU access
  };
  users.groups.ollama = {};
  
  # Set proper permissions for ollama directory
  systemd.tmpfiles.rules = [
    "d /var/lib/ollama 0755 ollama ollama -"
    "d /var/lib/ollama/.ollama 0755 ollama ollama -"
    "d /var/lib/ollama/.ollama/models 0755 ollama ollama -"
    "f /var/lib/ollama/.ollama/id_ed25519 0600 ollama ollama -"
  ];

  # Custom Ollama service with Intel OneAPI environment initialization
  systemd.services.ollama = {
    description = "Ollama with Intel IPEX support";
    wantedBy = [ "multi-user.target" ];
    after = [ "network.target" "systemd-tmpfiles-setup.service" ];
    
    environment = {
      # Intel SYCL/IPEX environment variables
      GGML_SYCL = "1";
      GGML_SYCL_F16 = "1";
      OLLAMA_INTEL_GPU = "1";
      
      # Intel OneAPI environment (from your Ubuntu script)
      ZES_ENABLE_SYSMAN = "1";
      SYCL_CACHE_PERSISTENT = "1";
      SYCL_PI_LEVEL_ZERO_USE_IMMEDIATE_COMMANDLISTS = "1";
      ONEAPI_DEVICE_SELECTOR = "level_zero:0";
      
      # Level-Zero debug environment variables
      ZE_DEBUG = "1";
      ZES_DEBUG = "1";
      ZE_ENABLE_VALIDATION_LAYER = "1";
      SYCL_PI_TRACE = "2";
      
      # Critical: Intel OpenCL ICD file location (from intel-dpcpp.clang component)
      OCL_ICD_FILENAMES = "${pkgs.intel-dpcpp.clang}/lib/libintelocl.so";
      
      # Intel OneAPI library paths (replicating setvars.sh)
      MKLROOT = "${pkgs.intel-mkl.out}";
      TBBROOT = "${pkgs.intel-tbb.out}";
      DNNLROOT = "${pkgs.intel-dpcpp.llvm}";  # Using dpcpp as closest equivalent
      
      # Intel include paths
      CPATH = "${pkgs.intel-mkl.out}/include:${pkgs.intel-dpcpp.llvm}/include";
      C_INCLUDE_PATH = "${pkgs.intel-mkl.out}/include:${pkgs.intel-tbb.out}/include";
      CPLUS_INCLUDE_PATH = "${pkgs.intel-mkl.out}/include:${pkgs.intel-tbb.out}/include:${pkgs.intel-dpcpp.llvm}/include";
      
      # Ollama configuration (from your working Ubuntu script)
      OLLAMA_DEBUG = "1";
      OLLAMA_KEEP_ALIVE = "5m";
      OLLAMA_HOST = "0.0.0.0:11434";
      OLLAMA_ORIGINS = "*";
      OLLAMA_NUM_GPU = "999";
      
      # Set proper home directory
      HOME = "/var/lib/ollama";
      OLLAMA_MODELS = "/var/lib/ollama/.ollama/models";
      
      # Bypass CPU detection issues (let BigDL auto-detect backend)
      # OLLAMA_LLM_LIBRARY = "oneapi";  # Commented out to let BigDL choose
      OLLAMA_SKIP_CPU_CHECK = "1";
    };
    
    serviceConfig = {
      Type = "exec";
      User = "ollama";
      Group = "ollama";
      ExecStart = pkgs.writeShellScript "ollama-with-ipex-env" ''
        # Add required commands to PATH for Intel vars.sh scripts
        export PATH="${pkgs.procps}/bin:${pkgs.gawk}/bin:$PATH"
        
        # Source Intel OneAPI environment scripts
        source ${pkgs.intel-mkl.out}/env/vars.sh
        source ${pkgs.intel-tbb.out}/env/vars.sh  
        source ${pkgs.intel-dpcpp.llvm}/env/vars.sh
        
        # Make our properly built IPEX-LLM available
        export PYTHONPATH="${pkgs.ipex-llm}/${pkgs.python3.sitePackages}:$PYTHONPATH"
        
        # Start standard Ollama with Intel IPEX environment
        exec ${pkgs.ollama}/bin/ollama serve
      '';
      Restart = "always";
      RestartSec = "3";
      WorkingDirectory = "/var/lib/ollama";
      StateDirectory = "ollama";
    };
  };
  
  # Open firewall for Ollama
  networking.firewall.allowedTCPPorts = [ 11434 ];
  #time.timeZone = "America/Los_Angeles";

  # Select internationalisation properties.
  i18n.defaultLocale = "en_US.UTF-8";

  i18n.extraLocaleSettings = {
    LC_ADDRESS = "en_US.UTF-8";
    LC_IDENTIFICATION = "en_US.UTF-8";
    LC_MEASUREMENT = "en_US.UTF-8";
    LC_MONETARY = "en_US.UTF-8";
    LC_NAME = "en_US.UTF-8";
    LC_NUMERIC = "en_US.UTF-8";
    LC_PAPER = "en_US.UTF-8";
    LC_TELEPHONE = "en_US.UTF-8";
    LC_TIME = "en_US.UTF-8";
  };

  # Enable the GDM Display Manager.
  services.displayManager = {
    defaultSession = "gnome";
  };
  #services.displayManager = {
  #  autoLogin.enable = true;
  #  autoLogin.user = "celes";
  #};
  services.xserver.displayManager = {
    setupCommands = "export WLR_BACKENDS=headless";
  };
  services.displayManager.gdm = {
    enable = true;
    wayland = true;
  };

  # Enable the X11 windowing system.
  services.xserver.enable = true;

  # Enable Desktop Environments
  services.desktopManager.gnome.enable = true;
  services.gnome.gnome-remote-desktop.enable = true;
  
  # Enable XFCE Desktop Environment (optimized for xrdp)
  services.xserver.desktopManager.xfce.enable = true;
  services.xserver.desktopManager.xfce.enableXfwm = true;
  services.xserver.desktopManager.xfce.enableScreensaver = false;
  
  # XFCE-specific services
  services.tumbler.enable = true;  # Thumbnail service
  services.gvfs.enable = true;     # Virtual filesystem
  programs.thunar.enable = true;   # File manager
  programs.thunar.plugins = with pkgs.xfce; [
    thunar-archive-plugin
    thunar-volman
    thunar-media-tags-plugin
  ];
  
  # Configure xrdp to use XFCE with Intel Arc Graphics acceleration
  services.xrdp.enable = true;
  services.xrdp.defaultWindowManager = "${pkgs.xfce.xfce4-session}/bin/xfce4-session";
  services.xrdp.openFirewall = true;
  
  # Use our custom xrdp package that references our Intel Arc glamor xorgxrdp
  services.xrdp.package = pkgs.xrdp;

  programs.hyprland = {
    # Install the packages from nixpkgs
    enable = true;
    package = pkgs.hyprland;
    # Whether to enable Xwayland
    xwayland.enable = true;
  };
  xdg.portal.wlr.enable = lib.mkForce false;

  programs.fish = {
    enable = true;
  };
  
  # Enable Location.
  services.geoclue2.enable = true;

  # Enable acpid
  services.acpid.enable = true;

  # Enable plymouth
  boot.plymouth.enable = true;

  # Configure keymap in X11
  services.xserver = {
    xkb.layout = "us";
    xkb.variant = "";
  };

  # Enable CUPS to print documents.
  services.printing.enable = true;

  # Enable sound with pipewire.
  services.pulseaudio.enable = false;
  security.rtkit.enable = true;
  
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    wireplumber.enable = true;
  };

  services.jack = {
    #jackd.enable = true;
    # support ALSA only programs via ALSA JACK PCM plugin
    alsa.enable = true;
    # support ALSA only programs via loopback device (supports programs like Steam)
    loopback = {
      enable = true;
      # buffering parameters for dmix device to work with ALSA only semi-professional sound programs
      #dmixConfig = ''
      #  period_size 2048
      #'';
    };
  };

  # Enable Fonts.
  fonts.packages = with pkgs-unstable; [
    noto-fonts
    noto-fonts-cjk-sans
    noto-fonts-color-emoji
    liberation_ttf
    fira-code
    fira-code-symbols
    mplus-outline-fonts.githubRelease
    dina-font
    proggyfonts
    fontconfig
    lexend
    nerd-fonts.dejavu-sans-mono
    nerd-fonts.space-mono
    material-symbols
    bibata-cursors
  ];

  # ADD: Intel IPEX support for GPU workloads in KubeVirt VM
  services.ipex = {
    enable = true;
    autoDetectHardware = true;
    devices = [ "gpu" ];
    optimization = "balanced";
  };

  # Extra Groups
  users.groups.mlocate = {};
  users.groups.plocate = {};

  security.sudo.configFile = ''
    root   ALL=(ALL:ALL) SETENV: ALL
    %wheel ALL=(ALL:ALL) SETENV: ALL
    celes  ALL=(ALL:ALL) SETENV: ALL
  '';

  # Gnome Keyring
  services.gnome.gnome-keyring.enable = true;

  # Enable touchpad support (enabled default in most desktopManager).
  services.libinput.enable = true;

  # Gestures.
  services.touchegg.enable = true;

  # Garbage Collection.
  nix.optimise.automatic = true;
 
  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.celes = {
    isNormalUser = true;
    description = "Celes Renata";
    extraGroups = [ "libvirtd" "networkmanager" "wheel" "input" "uinput" "render" "video" "audio" ];
    packages = with pkgs; [
      firefox
    #  thunderbird
    ];
  };

  # List packages installed in system profile. To search, run:
  # Enable Wayland for Electron.
  environment.sessionVariables.NIXOS_OZONE_WL = "1";
  environment.sessionVariables.MOZ_ENABLE_WAYLAND = "1";

  # $ nix search wget
  environment.systemPackages = 
  (with pkgs-stable; [
    # Editors.
    vim
    
    # Networking Tools.
    wget
    curl
    rsync
    nmap
    tmate

    # Audio.
    ladspaPlugins
    calf
    lsp-plugins
    alsa-utils

    # System Tools.
    mesa-demos
    intel-gpu-tools  # ADD: Intel GPU monitoring
    libva-utils      # ADD: Intel GPU capabilities
    nvtopPackages.intel  # GPU monitoring tool with Intel support
    
    # Intel GPU driver packages (from Ubuntu bootstrap script analysis)
    intel-compute-runtime  # Intel OpenCL runtime (equivalent to intel-opencl-icd)
    level-zero            # Level Zero GPU API
    intel-gmmlib          # Intel Graphics Memory Management Library
    
    blueman
    networkmanagerapplet
    nix-index
    mlocate
    barrier
    openssl
    simple-scan
    btop
    thefuck
    waypipe
    nh

    # Shells.
    fish
    zsh
    bash

    # Development Tools.
    git
    sublime4
    sqlite

    # Session.
    polkit
    polkit_gnome
    dconf
    killall
    gnome-keyring
    evtest
    zenity
    linux-pam
    cliphist
    sudo

    # Wayland.
    xwayland
    ydotool
    fcitx5
    wlsunset
    wtype
    wl-clipboard
    xorg.xhost
    wev
    wf-recorder
    mkvtoolnix-cli
    vulkan-tools
    libva-utils
    wofi
    libqalculate
    xfce.thunar
    wayland-scanner
    
    # GTK
    gtk3
    gtk3.dev
    libappindicator-gtk3.dev
    libnotify.dev
    gtk4
    gtk4.dev
    gjs
    gjs.dev
    gtksourceview
    gtksourceview.dev
    xdg-desktop-portal-gtk

    # Not GTK.
    tk

    # XFCE Desktop Environment - Core Components Only
    xfce.xfce4-panel
    xfce.xfce4-session
    xfce.xfwm4
    xfce.xfdesktop
    xfce.thunar
    xfce.xfce4-appfinder
    xfce.xfce4-settings
    xfce.xfce4-terminal
    xfce.xfce4-taskmanager
    xfce.xfce4-screenshooter
    xfce.xfce4-notifyd
    xfce.xfce4-power-manager
    xfce.xfce4-whiskermenu-plugin
    
    # XFCE Applications
    xfce.mousepad
    xfce.parole
    xfce.ristretto
    xfce.catfish
    
    # Essential applications
    firefox
    htop
    tree
    unzip
    zip
    file-roller
    feh
    evince
    gedit
    
    # Media codecs
    gst_all_1.gstreamer
    gst_all_1.gst-plugins-base
    gst_all_1.gst-plugins-good
  ])

  ++

  (with pkgs; [
    nil
    foot
    
    # ADD: Intel IPEX packages for GPU workloads
    comfyui-ipex      # ComfyUI with Intel XPU support
    ollama-sycl       # MordragT's Ollama with Intel SYCL (Go version fixed)
    ipex-benchmarks   # Performance testing suite
    kitty
    pulseaudio
    xdg-desktop-portal-hyprland
    hyprpaper
  ]);

  # List services that you want to enable:

  # Enable the OpenSSH daemon.
  services.openssh.enable = true;

  # Open ports in the firewall.
  # networking.firewall.allowedTCPPorts = [ ... ];
  # networking.firewall.allowedUDPPorts = [ ... ];
  # Or disable the firewall altogether.
  # networking.firewall.enable = false;

  # Steam
  programs.steam = {
    enable = true;
    extraPackages = with pkgs; [
      mesa-demos qt6.qtwayland nss xorg.libxkbfile
      kdePackages.qtwayland libsForQt5.qt5.qtwayland
      mangohud gamemode
    ];
    remotePlay.openFirewall = true;
    dedicatedServer.openFirewall = true;
  };
  hardware.steam-hardware.enable = true;

  # For more information, see `man configuration.nix` or https://nixos.org/manual/nixos/stable/options#opt-system.stateVersion .
  system.stateVersion = "24.11"; # Did you read the comment?
}

