#!/usr/bin/env bash

# Test script for Intel Arc Graphics xrdp configuration
# Usage: ./test-intel-arc.sh

set -e

echo "=== Intel Arc Graphics xrdp Configuration Test ==="
echo

# Check if we're in the right directory
if [[ ! -f "intel-arc-xorg.conf" ]]; then
    echo "ERROR: intel-arc-xorg.conf not found in current directory"
    exit 1
fi

echo "1. Current xorg.conf status:"
echo "   Driver in use: $(grep 'Driver ' /etc/X11/xrdp/xorg.conf | head -1)"
echo "   Device identifier: $(grep 'Identifier.*Video\|Identifier.*Intel' /etc/X11/xrdp/xorg.conf | head -1)"
echo

echo "2. Current OpenGL renderer:"
glxinfo | grep "OpenGL renderer" || echo "   glxinfo not available or no X session"
echo

echo "3. Hardware status:"
echo "   GPU: $(lspci | grep VGA)"
echo "   Driver: $(lspci -v -s 08:00.0 | grep 'Kernel driver in use')"
echo "   DRI devices: $(ls /dev/dri/ | tr '\n' ' ')"
echo

echo "4. Testing Intel Arc configuration..."
echo "   Backing up current xorg.conf..."
sudo cp /etc/X11/xrdp/xorg.conf /etc/X11/xrdp/xorg.conf.backup

echo "   Applying Intel Arc configuration..."
sudo cp intel-arc-xorg.conf /etc/X11/xrdp/xorg.conf

echo "   Restarting xrdp service..."
sudo systemctl restart xrdp

echo "   New configuration applied!"
echo "   Driver in use: $(grep 'Driver ' /etc/X11/xrdp/xorg.conf | head -1)"
echo "   Device identifier: $(grep 'Identifier.*Intel' /etc/X11/xrdp/xorg.conf | head -1)"
echo

echo "=== Test Complete ==="
echo "Next steps:"
echo "1. Connect via xrdp client"
echo "2. Run: glxinfo | grep renderer"
echo "3. Should show Intel Arc Graphics instead of llvmpipe"
echo
echo "To restore original config: sudo cp /etc/X11/xrdp/xorg.conf.backup /etc/X11/xrdp/xorg.conf"
