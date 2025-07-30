# XRDP Intel Arc Graphics Configuration Context

## Objective
Inject Intel Arc Graphics hardware acceleration configuration into xrdp's xorg.conf to replace software rendering (llvmpipe) with hardware-accelerated 3D rendering.

## Current Hardware Status
- **GPU**: Intel Corporation Meteor Lake-P [Intel Arc Graphics] (rev 08)
- **PCI Bus ID**: 08:00.0 (PCI:8:0:0 in xorg.conf format)
- **Kernel Driver**: i915 (confirmed via lspci -v)
- **Current Rendering**: llvmpipe (software rendering) - NEEDS TO BE FIXED

## Problem Analysis
1. Hardware passthrough IS working (Intel Arc GPU visible via lspci)
2. i915 kernel driver is loaded and functional
3. DRI devices exist: /dev/dri/card0 and /dev/dri/renderD128
4. User is in render group (confirmed)
5. BUT: xrdp sessions still use software rendering instead of Intel GPU

## Root Cause
The xrdp xorg.conf file is using the default `xrdpdev` driver configuration instead of Intel-specific hardware acceleration settings.

## Attempted Solutions
1. ✗ environment.etc override - NixOS appends default config after our custom config
2. ✗ services.xrdp.extraConfDirCommands patching - runs before xorg.conf generation
3. ✗ Direct file replacement during build - build order prevents this

## Current xorg.conf Status
- File location: /etc/X11/xrdp/xorg.conf
- Current driver: xrdpdev (software rendering)
- Target driver: intel with proper Intel Arc Graphics configuration

## Next Steps Required
Need to find a way to completely override the NixOS-generated xorg.conf with our Intel Arc configuration that includes:
- Driver "intel" 
- BusID "PCI:8:0:0"
- Option "DRI" "3"
- Option "AccelMethod" "sna"
- Proper device and screen section references
