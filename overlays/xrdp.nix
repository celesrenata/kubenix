final: prev:
{
  # Override xrdp with newer version and DRM support, using our custom xorgxrdp-glamor
  xrdp = prev.xrdp.overrideAttrs (oldAttrs: {
    version = "0.10.4.1";
    
    src = prev.fetchFromGitHub {
      owner = "neutrinolabs";
      repo = "xrdp";
      rev = "v0.10.4.1";
      fetchSubmodules = true;
      sha256 = "sha256-ula1B9/eriJ+0r6d9r2LAzh7J3s6/uvAiTKeRzLuVL0=";
    };

    # Ensure we have all the build inputs including DRM support
    buildInputs = (oldAttrs.buildInputs or []) ++ (with prev; [
      lame
      libopus
      systemd
      fuse3
      libjpeg_turbo.dev
      libdrm
      mesa
    ]);

    # Add configure flags for enhanced features including DRM
    configureFlags = (oldAttrs.configureFlags or []) ++ [
      "--enable-fuse"
      "--enable-pam-config=unix"
      "--enable-ipv6"
      "--enable-jpeg"
      "--enable-opus"
      "--enable-mp3lame"
      "--enable-glamor"
      "--enable-drm"
      "--with-systemdsystemunitdir=${placeholder "out"}/lib/systemd/system"
    ];

    # Add custom PAM configuration and ensure NixOS compatibility
    postInstall = (oldAttrs.postInstall or "") + ''
      # Add the rsakeys_ini line that NixOS module expects
      # Insert it after the certificate= line in the [Globals] section
      if [ -f $out/etc/xrdp/xrdp.ini ]; then
        sed -i '/^certificate=/a #rsakeys_ini=' $out/etc/xrdp/xrdp.ini
      fi
      
      # Create more permissive PAM configuration for xrdp login
      mkdir -p $out/etc/pam.d
      
      cat > $out/etc/pam.d/xrdp-sesman << 'PAMEOF'
#%PAM-1.0
auth       sufficient   pam_unix.so nullok
account    sufficient   pam_unix.so
password   sufficient   pam_unix.so nullok sha512 shadow
session    required     pam_unix.so
session    optional     pam_systemd.so
PAMEOF
    '';
  });

  # Make sure xrdp uses our custom xorgxrdp-glamor with Intel Arc config
  inherit (final) xorgxrdp-glamor;
}
