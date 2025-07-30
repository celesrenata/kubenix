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
    noto-fonts-emoji
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
    glxinfo
    intel-gpu-tools  # ADD: Intel GPU monitoring
    libva-utils      # ADD: Intel GPU capabilities
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

  # For more information, see `man configuration.nix` or https://nixos.org/manual/nixos/stable/options#opt-system.stateVersion .
  system.stateVersion = "24.11"; # Did you read the comment?
}

