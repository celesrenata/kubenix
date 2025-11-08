final: prev:
let
  glamorPatch = prev.fetchurl {
    url = "https://aur.archlinux.org/cgit/aur.git/plain/glamor.patch?h=xorgxrdp-glamor";
    sha256 = "sha256-CqCye2YSIhe9bKJGZJb+O+hzjE3r4kf5r3/aoISHYi4=";
  };
in
{
  # Override the regular xorgxrdp package with glamor support and Intel Arc config
  xorgxrdp = prev.stdenv.mkDerivation {
    pname = "xorgxrdp";
    version = "v0.10.4-intel-arc-glamor-xe"; # Use latest 0.10.4 version
    src = prev.fetchFromGitHub {
      owner = "neutrinolabs";
      repo = "xorgxrdp";
      rev = "v0.10.4";  # Use the 0.10.4 tag
      sha256 = "sha256-TuzUerfOn8+3YfueG00IBP9sMpvy2deyL16mWQ8cRHg=";
    };

    # Add glamor patch back for 3D acceleration
    patches = [ glamorPatch ];
    
    # Patch to fix drm_fourcc.h include path
    postPatch = ''
      # Fix the include paths for DRM headers
      sed -i 's|#include <drm_fourcc.h>|#include <libdrm/drm_fourcc.h>|g' module/rdpEgl.c
      sed -i 's|#include <drm.h>|#include <libdrm/drm.h>|g' xrdpdev/xrdpdri2.c
      sed -i 's|#include <drm_mode.h>|#include <libdrm/drm_mode.h>|g' xrdpdev/xrdpdri2.c
    '';

    nativeBuildInputs = with prev; [
      autoreconfHook
    ];

    buildInputs = with prev; [
      autoconf
      automake
      libtool
      pkg-config
      libdrm
      libdrm.dev  # Add libdrm development headers
      mesa
      libgbm  # Add libgbm for GBM support
      nasm
      xorg.xorgserver
      xrdp
      linuxHeaders  # Add kernel headers for DRM
    ];
    env.NIX_CFLAGS_COMPILE = "-ffat-lto-objects -I${prev.libdrm.dev}/include/libdrm";
    preConfigure = ''
      ./bootstrap
    '';
    configureFlags = [
      "--enable-glamor"  # Re-enable glamor for 3D acceleration!
      "--prefix=$out"
      "--with-xorg-module-dir=$out/lib/xorg/modules"
    ];
    buildPhase = ''
      make all
    '';
    
    installPhase = ''
      mkdir -p $out/lib/xorg/modules
      mkdir -p $out/lib/xorg/modules/drivers
      mkdir -p $out/lib/xorg/modules/input
      mkdir -p $out/etc/X11/xrdp
      
      # Install the modules
      cp module/.libs/libxorgxrdp.so $out/lib/xorg/modules/
      cp xrdpdev/.libs/xrdpdev_drv.so $out/lib/xorg/modules/drivers/
      cp xrdpmouse/.libs/xrdpmouse_drv.so $out/lib/xorg/modules/input/
      cp xrdpkeyb/.libs/xrdpkeyb_drv.so $out/lib/xorg/modules/input/
      
      # Create Intel Arc xorg.conf with xrdpdev driver
      cat > $out/etc/X11/xrdp/xorg.conf << 'EOF'
Section "ServerLayout"
    Identifier "X11 Server"
    Screen "Screen (xrdpdev)"
    InputDevice "xrdpMouse" "CorePointer"
    InputDevice "xrdpKeyboard" "CoreKeyboard"
EndSection

Section "ServerFlags"
    # This line prevents "ServerLayout" sections in xorg.conf.d files
    # overriding the "X11 Server" layout (xrdp #1784)
    Option "DefaultServerLayout" "X11 Server"
    Option "DontVTSwitch" "on"
    Option "AutoAddDevices" "off"
    Option "AutoAddGPU" "off"
EndSection

Section "Module"
    Load "dbe"
    Load "ddc"
    Load "extmod"
    Load "glx"
    Load "int10"
    Load "record"
    Load "vbe"
    Load "xorgxrdp"
    Load "fb"
EndSection

Section "InputDevice"
    Identifier "xrdpKeyboard"
    Driver "xrdpkeyb"
EndSection

Section "InputDevice"
    Identifier "xrdpMouse"
    Driver "xrdpmouse"
EndSection

Section "Monitor"
    Identifier "Monitor"
    Option "DPMS"
    HorizSync 30-80
    VertRefresh 60-75
    ModeLine "1920x1080" 138.500 1920 1968 2000 2080 1080 1083 1088 1111 +hsync -vsync
    ModeLine "1280x720" 74.25 1280 1720 1760 1980 720 725 730 750 +HSync +VSync
    Modeline "1368x768" 72.25 1368 1416 1448 1528 768 771 781 790 +hsync -vsync
    Modeline "1600x900" 119.00 1600 1696 1864 2128 900 901 904 932 -hsync +vsync
EndSection

Section "Device"
    Identifier "Video Card (xrdpdev)"
    Driver "xrdpdev"
    Option "DRMDevice" "/dev/dri/renderD128"
    Option "DRI3" "1"
    Option "DRMAllowList" "amdgpu i915 msm radeon xe"
EndSection

Section "Screen"
    Identifier "Screen (xrdpdev)"
    Device "Video Card (xrdpdev)"
    # Comment out this line for xorg < 1.18.0
    GPUDevice ""
    Monitor "Monitor"
    DefaultDepth 24
    SubSection "Display"
        Depth 24
        Modes "640x480" "800x600" "1024x768" "1280x720" "1280x1024" "1600x900" "1920x1080"
    EndSubSection
EndSection
EOF
    '';
    
    # Sly approach: Replace the default xorg.conf with Intel Arc configuration
    postInstall = ''
      # Replace the bundled xorg.conf with our Intel Arc configuration
      cat > $out/etc/X11/xrdp/xorg.conf << 'EOF'
Section "ServerLayout"
    Identifier "X11 Server"
    Screen "Screen (intel)"
    InputDevice "xrdpMouse" "CorePointer"
    InputDevice "xrdpKeyboard" "CoreKeyboard"
EndSection

Section "ServerFlags"
    Option "DefaultServerLayout" "X11 Server"
    Option "DontVTSwitch" "on"
    Option "AutoAddDevices" "off"
    Option "AutoAddGPU" "off"
EndSection

Section "Module"
    Load "dbe"
    Load "ddc"
    Load "extmod"
    Load "glx"
    Load "int10"
    Load "record"
    Load "vbe"
    Load "xorgxrdp"
    Load "fb"
EndSection

Section "InputDevice"
    Identifier "xrdpKeyboard"
    Driver "xrdpkeyb"
EndSection

Section "InputDevice"
    Identifier "xrdpMouse"
    Driver "xrdpmouse"
EndSection

Section "Monitor"
    Identifier "Monitor"
    Option "DPMS"
    HorizSync 30-80
    VertRefresh 60-75
    ModeLine "1920x1080" 138.500 1920 1968 2000 2080 1080 1083 1088 1111 +hsync -vsync
    ModeLine "1280x720" 74.25 1280 1720 1760 1980 720 725 730 750 +HSync +VSync
    Modeline "1368x768" 72.25 1368 1416 1448 1528 768 771 781 790 +hsync -vsync
    Modeline "1600x900" 119.00 1600 1696 1864 2128 900 901 904 932 -hsync +vsync
EndSection

Section "Device"
    Identifier "Intel Arc Graphics"
    Driver "modesetting"
    BusID "PCI:8:0:0"
    Option "DRI" "3"
    Option "AccelMethod" "glamor"
    
EndSection

Section "Screen"
    Identifier "Screen (intel)"
    Device "Intel Arc Graphics"
    Monitor "Monitor"
    DefaultDepth 24
    SubSection "Display"
        Depth 24
        Modes "640x480" "800x600" "1024x768" "1280x720" "1280x1024" "1600x900" "1920x1080"
    EndSubSection
EndSection
EOF
    '';
  };

  # Override xrdp to use our custom xorgxrdp package with Intel Arc glamor support
  xrdp = prev.xrdp.overrideAttrs (oldAttrs: {
    # Force rebuild by changing version
    version = "${oldAttrs.version}-intel-arc-glamor";
    __intentionallyOverridingVersion = true;
    
    # Disable RFX codec to prevent EGFX crashes
    configureFlags = (oldAttrs.configureFlags or []) ++ [
      "--disable-rfxcodec"
    ];
    
    # Override postInstall to reference our custom xorgxrdp package
    postInstall = ''
      # remove generated keys (as non-deterministic)
      rm $out/etc/xrdp/{rsakeys.ini,key.pem,cert.pem}

      cp $src/keygen/openssl.conf $out/share/xrdp/openssl.conf

      substituteInPlace $out/etc/xrdp/sesman.ini --replace-fail /etc/xrdp/pulse $out/etc/xrdp/pulse
      substituteInPlace $out/etc/xrdp/sesman.ini --replace-fail '#SessionSockdirGroup=xrdp' 'SessionSockdirGroup=xrdp'

      # Add the missing rsakeys_ini pattern that NixOS service expects
      echo "#rsakeys_ini=" >> $out/etc/xrdp/xrdp.ini

      # Disable GFX encoding comprehensively to prevent process_enc_egfx crashes
      echo "gfx_decode=no" >> $out/etc/xrdp/xrdp.ini
      echo "gfx_h264=no" >> $out/etc/xrdp/xrdp.ini
      echo "gfx_progressive=no" >> $out/etc/xrdp/xrdp.ini
      echo "egfx=no" >> $out/etc/xrdp/xrdp.ini
      echo "use_fastpath=no" >> $out/etc/xrdp/xrdp.ini
      echo "allow_channels=false" >> $out/etc/xrdp/xrdp.ini
      echo "bitmap_compression=false" >> $out/etc/xrdp/xrdp.ini

      # remove all session types except Xorg (they are not supported by this setup)
      perl -i -ne 'print unless /\[(X11rdp|Xvnc|console|vnc-any|sesman-any|rdp-any|neutrinordp-any)\]/ .. /^$/' $out/etc/xrdp/xrdp.ini

      # remove all session types and then add Xorg
      perl -i -ne 'print unless /\[(X11rdp|Xvnc|Xorg)\]/ .. /^$/' $out/etc/xrdp/sesman.ini

      cat >> $out/etc/xrdp/sesman.ini <<EOF

[Xorg]
param=${prev.xorg.xorgserver}/bin/Xorg
param=-modulepath
param=${final.xorgxrdp}/lib/xorg/modules,${prev.xorg.xorgserver}/lib/xorg/modules
param=-config
param=${final.xorgxrdp}/etc/X11/xrdp/xorg.conf
param=-noreset
param=-nolisten
param=tcp
param=-logfile
param=.xorgxrdp.%s.log
EOF
    '';
  });

}
