# Implementation Roadmap: Intel Arc Graphics xrdp Configuration

## Phase 1: Validation (CURRENT)
**Objective**: Confirm our Intel Arc xorg.conf works before making it persistent

### Steps:
1. ✅ Created context files and Intel Arc configuration
2. ⏳ Run `./test-intel-arc.sh` to test configuration manually
3. ⏳ Connect via xrdp and verify hardware acceleration works
4. ⏳ Confirm `glxinfo | grep renderer` shows Intel Arc instead of llvmpipe

### Success Criteria:
- xrdp sessions use Intel Arc Graphics for rendering
- 3D acceleration works properly
- No crashes or display issues

## Phase 2: NixOS Integration (NEXT)
**Objective**: Make the configuration persistent through NixOS

### Option A: Activation Script (Recommended)
```nix
system.activationScripts.xrdp-intel-patch = ''
  cp ${./intel-arc-xorg.conf} /etc/X11/xrdp/xorg.conf
  chmod 644 /etc/X11/xrdp/xorg.conf
'';
```

### Option B: systemd Service
```nix
systemd.services.xrdp-intel-patch = {
  description = "Apply Intel Arc Graphics configuration to xrdp";
  after = [ "xrdp.service" ];
  wantedBy = [ "multi-user.target" ];
  serviceConfig = {
    Type = "oneshot";
    ExecStart = "${pkgs.coreutils}/bin/cp ${./intel-arc-xorg.conf} /etc/X11/xrdp/xorg.conf";
    RemainAfterExit = true;
  };
};
```

## Phase 3: Testing & Validation
**Objective**: Ensure the persistent solution works across reboots

### Steps:
1. Apply NixOS configuration with chosen approach
2. Rebuild system: `sudo nixos-rebuild switch --flake ~/sources/nixos#kubenix`
3. Reboot system
4. Verify xorg.conf is still using Intel Arc configuration
5. Test xrdp sessions still have hardware acceleration

## Phase 4: Optimization (FUTURE)
**Objective**: Fine-tune Intel Arc settings for optimal performance

### Potential Improvements:
- Test different AccelMethod options (sna, uxa, glamor)
- Optimize TearFree settings
- Add Intel-specific performance options
- Test with different resolution modes

## Current Status
- **Phase**: 1 (Validation)
- **Next Action**: Run `./test-intel-arc.sh`
- **Files Ready**: 
  - ✅ intel-arc-xorg.conf (target configuration)
  - ✅ test-intel-arc.sh (validation script)
  - ✅ Context documentation
