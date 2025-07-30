# Alternative Approaches to Inject Intel Arc xorg.conf

## Approach 1: systemd Service Override (POST-BUILD)
Create a systemd service that runs after xrdp starts and replaces the xorg.conf file.

**Pros**: Runs after NixOS generation, guaranteed to override
**Cons**: Hacky, might be overwritten on service restart

```nix
systemd.services.xrdp-intel-patch = {
  description = "Patch xrdp xorg.conf for Intel Arc Graphics";
  after = [ "xrdp.service" ];
  wantedBy = [ "multi-user.target" ];
  serviceConfig = {
    Type = "oneshot";
    ExecStart = "${pkgs.coreutils}/bin/cp ${./intel-arc-xorg.conf} /etc/X11/xrdp/xorg.conf";
    RemainAfterExit = true;
  };
};
```

## Approach 2: environment.etc with Higher Priority
Use NixOS's environment.etc with a higher priority to override the xrdp-generated file.

```nix
environment.etc."X11/xrdp/xorg.conf" = {
  mode = "0644";
  source = ./intel-arc-xorg.conf;
  # Try to override xrdp's generated file
};
```

## Approach 3: Custom xrdp Package Override
Override the xrdp package to use our custom xorg.conf template.

**Pros**: Clean, integrated with NixOS
**Cons**: Complex, requires package override

## Approach 4: Symlink Replacement in activation script
Use NixOS activation scripts to replace the file after system activation.

```nix
system.activationScripts.xrdp-intel-patch = ''
  cp ${./intel-arc-xorg.conf} /etc/X11/xrdp/xorg.conf
  chmod 644 /etc/X11/xrdp/xorg.conf
'';
```

## Approach 5: Direct File Manipulation (Runtime)
Manually replace the file and test, then find a way to make it persistent.

```bash
# Test approach
sudo cp intel-arc-xorg.conf /etc/X11/xrdp/xorg.conf
sudo systemctl restart xrdp
# Test if it works, then implement in NixOS config
```

## Recommended Next Steps
1. Try Approach 5 (direct manipulation) to validate the configuration works
2. If successful, implement Approach 4 (activation script) for persistence
3. If that fails, fall back to Approach 1 (systemd service)
