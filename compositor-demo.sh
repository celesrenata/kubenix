#!/usr/bin/env bash

# XFCE Compositor Effects Demo
# This script demonstrates different compositor effect presets

echo "🎨 XFCE Compositor Effects Demo"
echo "==============================="

demo_xfwm4_preset() {
    local name="$1"
    local frame_opacity="$2"
    local inactive_opacity="$3"
    local move_opacity="$4"
    local shadows="$5"
    
    echo "🔧 Applying XFWM4 preset: $name"
    
    # Stop picom if running
    pkill picom 2>/dev/null
    
    xfconf-query -c xfwm4 -p /general/use_compositing -s true
    xfconf-query -c xfwm4 -p /general/frame_opacity -s "$frame_opacity"
    xfconf-query -c xfwm4 -p /general/inactive_opacity -s "$inactive_opacity"
    xfconf-query -c xfwm4 -p /general/move_opacity -s "$move_opacity"
    xfconf-query -c xfwm4 -p /general/popup_opacity -s "$frame_opacity"
    xfconf-query -c xfwm4 -p /general/resize_opacity -s "$move_opacity"
    xfconf-query -c xfwm4 -p /general/show_frame_shadow -s "$shadows"
    xfconf-query -c xfwm4 -p /general/show_popup_shadow -s false
    
    echo "   Frame opacity: $frame_opacity%"
    echo "   Inactive opacity: $inactive_opacity%"
    echo "   Move opacity: $move_opacity%"
    echo "   Shadows: $shadows"
    echo ""
}

demo_picom_preset() {
    local name="$1"
    local config="$2"
    
    echo "🔧 Applying Picom preset: $name"
    
    # Disable XFCE compositor
    xfconf-query -c xfwm4 -p /general/use_compositing -s false
    
    # Stop any existing picom
    pkill picom 2>/dev/null
    sleep 1
    
    # Start picom with config
    echo "$config" > /tmp/picom-demo.conf
    picom --config /tmp/picom-demo.conf --daemon
    
    echo "   Picom started with $name configuration"
    echo ""
}

show_menu() {
    echo "Choose a compositor preset:"
    echo ""
    echo "XFCE Built-in Compositor (xfwm4):"
    echo "1) No Effects (Compositor Off)"
    echo "2) Minimal Effects (Shadows only)"
    echo "3) Subtle Effects (Light transparency)"
    echo "4) Moderate Effects (Medium transparency)"
    echo "5) Strong Effects (High transparency)"
    echo "6) Gaming Mode (Performance optimized)"
    echo ""
    echo "Picom Compositor (Advanced):"
    echo "7) Picom Basic (Simple effects)"
    echo "8) Picom Blur (Background blur)"
    echo "9) Picom Animations (Smooth transitions)"
    echo "10) Picom Gaming (Performance focused)"
    echo ""
    echo "11) Current Status"
    echo "12) Exit"
    echo ""
}

get_picom_basic_config() {
    cat << 'EOF'
# Basic Picom Configuration
backend = "glx";
vsync = true;
shadow = true;
shadow-radius = 7;
shadow-offset-x = -7;
shadow-offset-y = -7;
shadow-opacity = 0.7;
fading = true;
fade-in-step = 0.03;
fade-out-step = 0.03;
inactive-opacity = 0.9;
frame-opacity = 0.9;
inactive-opacity-override = false;
EOF
}

get_picom_blur_config() {
    cat << 'EOF'
# Picom with Blur Effects
backend = "glx";
vsync = true;
shadow = true;
shadow-radius = 12;
shadow-offset-x = -12;
shadow-offset-y = -12;
shadow-opacity = 0.8;
fading = true;
fade-in-step = 0.05;
fade-out-step = 0.05;
inactive-opacity = 0.85;
frame-opacity = 0.9;
blur-background = true;
blur-method = "dual_kawase";
blur-strength = 5;
blur-background-exclude = [
    "window_type = 'dock'",
    "window_type = 'desktop'"
];
EOF
}

get_picom_animations_config() {
    cat << 'EOF'
# Picom with Smooth Animations
backend = "glx";
vsync = true;
shadow = true;
shadow-radius = 10;
shadow-offset-x = -10;
shadow-offset-y = -10;
shadow-opacity = 0.75;
fading = true;
fade-in-step = 0.08;
fade-out-step = 0.08;
fade-delta = 10;
inactive-opacity = 0.8;
frame-opacity = 0.95;
active-opacity = 1.0;
wintypes = {
    tooltip = { fade = true; shadow = true; opacity = 0.9; focus = true; full-shadow = false; };
    dock = { shadow = false; };
    dnd = { shadow = false; };
    popup_menu = { opacity = 0.9; };
    dropdown_menu = { opacity = 0.9; };
};
EOF
}

get_picom_gaming_config() {
    cat << 'EOF'
# Picom Gaming Configuration (Performance)
backend = "glx";
vsync = false;
shadow = false;
fading = false;
inactive-opacity = 1.0;
frame-opacity = 1.0;
active-opacity = 1.0;
blur-background = false;
EOF
}

while true; do
    show_menu
    read -p "Enter your choice (1-12): " choice
    echo ""
    
    case $choice in
        1)
            echo "🔧 Disabling all compositors..."
            pkill picom 2>/dev/null
            xfconf-query -c xfwm4 -p /general/use_compositing -s false
            echo "❌ All compositors disabled"
            ;;
        2)
            demo_xfwm4_preset "Minimal Effects" 100 100 100 true
            ;;
        3)
            demo_xfwm4_preset "Subtle Effects" 95 90 95 true
            ;;
        4)
            demo_xfwm4_preset "Moderate Effects" 85 75 85 true
            ;;
        5)
            demo_xfwm4_preset "Strong Effects" 70 60 75 true
            ;;
        6)
            demo_xfwm4_preset "Gaming Mode" 100 95 100 false
            ;;
        7)
            demo_picom_preset "Basic" "$(get_picom_basic_config)"
            ;;
        8)
            demo_picom_preset "Blur" "$(get_picom_blur_config)"
            ;;
        9)
            demo_picom_preset "Animations" "$(get_picom_animations_config)"
            ;;
        10)
            demo_picom_preset "Gaming" "$(get_picom_gaming_config)"
            ;;
        11)
            echo "📊 Current Compositor Status:"
            if pgrep picom >/dev/null; then
                echo "   Active Compositor: Picom"
                echo "   PID: $(pgrep picom)"
            elif xfconf-query -c xfwm4 -p /general/use_compositing 2>/dev/null | grep -q "true"; then
                echo "   Active Compositor: XFWM4"
                echo "   Frame opacity: $(xfconf-query -c xfwm4 -p /general/frame_opacity 2>/dev/null)%"
                echo "   Inactive opacity: $(xfconf-query -c xfwm4 -p /general/inactive_opacity 2>/dev/null)%"
                echo "   Shadows: $(xfconf-query -c xfwm4 -p /general/show_frame_shadow 2>/dev/null)"
            else
                echo "   Active Compositor: None"
            fi
            ;;
        12)
            echo "👋 Exiting compositor demo"
            exit 0
            ;;
        *)
            echo "❌ Invalid choice. Please enter 1-12."
            ;;
    esac
    
    echo ""
    echo "💡 Effects applied! Move windows around to see the changes."
    echo "Press Enter to continue..."
    read -r
    echo ""
done
