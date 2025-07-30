#!/usr/bin/env bash

# XFCE Compositor Toggle Script
# This script helps you enable/disable and configure XFCE's built-in compositor

show_status() {
    echo "=== XFCE Compositor Status ==="
    if xfconf-query -c xfwm4 -p /general/use_compositing 2>/dev/null | grep -q "true"; then
        echo "✅ Compositor: ENABLED"
        echo "Frame opacity: $(xfconf-query -c xfwm4 -p /general/frame_opacity 2>/dev/null || echo 'Not set')"
        echo "Show shadows: $(xfconf-query -c xfwm4 -p /general/show_frame_shadow 2>/dev/null || echo 'Not set')"
    else
        echo "❌ Compositor: DISABLED"
    fi
    echo
}

enable_compositor() {
    echo "🔧 Enabling XFCE compositor with effects..."
    xfconf-query -c xfwm4 -p /general/use_compositing -s true
    xfconf-query -c xfwm4 -p /general/frame_opacity -s 100
    xfconf-query -c xfwm4 -p /general/inactive_opacity -s 100
    xfconf-query -c xfwm4 -p /general/move_opacity -s 100
    xfconf-query -c xfwm4 -p /general/popup_opacity -s 100
    xfconf-query -c xfwm4 -p /general/resize_opacity -s 100
    xfconf-query -c xfwm4 -p /general/show_frame_shadow -s true
    xfconf-query -c xfwm4 -p /general/show_popup_shadow -s false
    echo "✅ Compositor enabled!"
}

disable_compositor() {
    echo "🔧 Disabling XFCE compositor..."
    xfconf-query -c xfwm4 -p /general/use_compositing -s false
    echo "❌ Compositor disabled!"
}

enable_transparency() {
    echo "🔧 Enabling window transparency effects..."
    xfconf-query -c xfwm4 -p /general/use_compositing -s true
    xfconf-query -c xfwm4 -p /general/frame_opacity -s 85
    xfconf-query -c xfwm4 -p /general/inactive_opacity -s 75
    xfconf-query -c xfwm4 -p /general/move_opacity -s 85
    xfconf-query -c xfwm4 -p /general/popup_opacity -s 90
    xfconf-query -c xfwm4 -p /general/resize_opacity -s 85
    echo "✅ Transparency effects enabled!"
}

case "$1" in
    "status"|"")
        show_status
        ;;
    "enable")
        enable_compositor
        show_status
        ;;
    "disable")
        disable_compositor
        show_status
        ;;
    "transparency")
        enable_transparency
        show_status
        ;;
    "help")
        echo "XFCE Compositor Control Script"
        echo
        echo "Usage: $0 [command]"
        echo
        echo "Commands:"
        echo "  status       Show current compositor status (default)"
        echo "  enable       Enable compositor with basic effects"
        echo "  disable      Disable compositor"
        echo "  transparency Enable compositor with transparency effects"
        echo "  help         Show this help message"
        echo
        echo "Note: Changes take effect immediately in XFCE"
        ;;
    *)
        echo "Unknown command: $1"
        echo "Use '$0 help' for usage information"
        exit 1
        ;;
esac
