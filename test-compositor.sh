#!/usr/bin/env bash

# XFCE Compositor Test Script
# This script tests various compositor features

echo "🧪 Testing XFCE Compositor Features"
echo "=================================="

# Test 1: Check if compositor is running
echo "1. Checking compositor status..."
if xfconf-query -c xfwm4 -p /general/use_compositing 2>/dev/null | grep -q "true"; then
    echo "   ✅ Compositor is enabled"
else
    echo "   ❌ Compositor is disabled"
    exit 1
fi

# Test 2: Check OpenGL/hardware acceleration
echo "2. Checking graphics capabilities..."
if command -v glxinfo >/dev/null 2>&1; then
    RENDERER=$(glxinfo | grep "OpenGL renderer" | cut -d: -f2 | xargs)
    VENDOR=$(glxinfo | grep "OpenGL vendor" | cut -d: -f2 | xargs)
    echo "   Graphics: $VENDOR - $RENDERER"
    
    if glxinfo | grep -q "direct rendering: Yes"; then
        echo "   ✅ Hardware acceleration: Enabled"
    else
        echo "   ⚠️  Hardware acceleration: Disabled"
    fi
else
    echo "   ⚠️  glxinfo not available"
fi

# Test 3: Test window effects
echo "3. Testing window effects..."
echo "   Current opacity settings:"
echo "   - Frame opacity: $(xfconf-query -c xfwm4 -p /general/frame_opacity 2>/dev/null || echo 'Not set')"
echo "   - Inactive opacity: $(xfconf-query -c xfwm4 -p /general/inactive_opacity 2>/dev/null || echo 'Not set')"
echo "   - Move opacity: $(xfconf-query -c xfwm4 -p /general/move_opacity 2>/dev/null || echo 'Not set')"

# Test 4: Test shadow effects
echo "4. Testing shadow effects..."
if xfconf-query -c xfwm4 -p /general/show_frame_shadow 2>/dev/null | grep -q "true"; then
    echo "   ✅ Window shadows: Enabled"
else
    echo "   ❌ Window shadows: Disabled"
fi

# Test 5: Launch a test window to demonstrate effects
echo "5. Launching test window..."
echo "   Opening a terminal window to test transparency..."
echo "   (You should see transparency effects on the window)"

# Launch a semi-transparent terminal for visual testing
if command -v xfce4-terminal >/dev/null 2>&1; then
    xfce4-terminal --title="Compositor Test Window" --geometry=60x20 &
    TEST_PID=$!
    echo "   ✅ Test terminal launched (PID: $TEST_PID)"
    echo "   💡 Move the window around to see opacity effects!"
    echo "   💡 The window should have shadows and transparency"
    echo ""
    echo "Press Enter to close the test window and continue..."
    read -r
    kill $TEST_PID 2>/dev/null
else
    echo "   ⚠️  xfce4-terminal not available for visual test"
fi

echo ""
echo "🎉 Compositor test completed!"
echo "If you saw transparency and shadow effects, the compositor is working correctly."
