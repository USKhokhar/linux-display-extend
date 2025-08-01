#!/bin/bash
# Linux Display Extend - Main Script (modular source)
# Author: USKhokhar (https://github.com/USKhokhar)
# Email: contact.uskhokhar@gmail.com
# Twitter: https://twitter.com/US_Khokhar
# Portfolio: https://uskhokhar.vercel.app
# Repository: https://github.com/USKhokhar/linux-display-extend
# Version 1.0

SCRIPT_DIR="/usr/share/linux-display-extend"
CONFIG_DIR="$HOME/.config/linux-display-extend"
CONFIG_FILE="$CONFIG_DIR/config"

# Create config directory if it doesn't exist
mkdir -p "$CONFIG_DIR"

# Default configuration
DEFAULT_WIDTH="1280"
DEFAULT_HEIGHT="720"
DEFAULT_POSITION="right"

# Load or create configuration
load_config() {
    if [[ -f "$CONFIG_FILE" ]]; then
        source "$CONFIG_FILE"
    else
        cat > "$CONFIG_FILE" << CONF
# Linux Display Extend Configuration
DISPLAY_WIDTH=$DEFAULT_WIDTH
DISPLAY_HEIGHT=$DEFAULT_HEIGHT
DISPLAY_POSITION=$DEFAULT_POSITION
CONF
        DISPLAY_WIDTH=$DEFAULT_WIDTH
        DISPLAY_HEIGHT=$DEFAULT_HEIGHT
        DISPLAY_POSITION=$DEFAULT_POSITION
    fi
}

# Show help
show_help() {
    echo "Linux Display Extend v1.0"
    echo "Use your Android display as an extended display"
    echo ""
    echo "Usage:"
    echo "  display-extend start                 - Start extended display"
    echo "  display-extend stop                  - Stop extended display"
    echo "  display-extend status                - Show current status"
    echo "  display-extend config                - Configure display settings"
    echo "  display-extend install-vnc           - Install VNC viewer on display"
    echo "  display-extend --help                - Show this help"
    echo ""
    echo "Configuration:"
    echo "  Edit ~/.config/linux-display-extend/config"
    echo "  or run 'display-extend config' for interactive setup"
}

# Interactive configuration
configure() {
    echo "=== Linux Display Extend Configuration ==="
    echo ""
    echo "Current settings:"
    echo "  Resolution: ${DISPLAY_WIDTH}x${DISPLAY_HEIGHT}"
    echo "  Position: $DISPLAY_POSITION of main display"
    echo ""
    
    read -p "Enter display resolution width (default: $DISPLAY_WIDTH): " width
    read -p "Enter display resolution height (default: $DISPLAY_HEIGHT): " height
    read -p "Position relative to main display [left/right/above/below] (default: $DISPLAY_POSITION): " position
    
    # Use defaults if empty
    width=${width:-$DISPLAY_WIDTH}
    height=${height:-$DISPLAY_HEIGHT}
    position=${position:-$DISPLAY_POSITION}
    
    # Update config file
    cat > "$CONFIG_FILE" << CONF
# Linux Display Extend Configuration
DISPLAY_WIDTH=$width
DISPLAY_HEIGHT=$height
DISPLAY_POSITION=$position
CONF
    
    echo "Configuration saved to $CONFIG_FILE"
    DISPLAY_WIDTH=$width
    DISPLAY_HEIGHT=$height
    DISPLAY_POSITION=$position
}

# Get main display info
get_main_display() {
    MAIN_DISPLAY=$(xrandr | grep " connected primary" | cut -d' ' -f1)
    MAIN_RES=$(xrandr | grep "$MAIN_DISPLAY" | grep -o "[0-9]*x[0-9]*" | head -1)
    MAIN_WIDTH=$(echo $MAIN_RES | cut -d'x' -f1)
    MAIN_HEIGHT=$(echo $MAIN_RES | cut -d'x' -f2)
}

# Start extended display
start_extended() {
    echo "Starting Linux Display Extend (true extended mode)..."

    # Get your laptop's main resolution first
    MAIN_RES=$(xrandr | grep "eDP-1" | grep -o "[0-9]*x[0-9]*" | head -1)
    MAIN_WIDTH=$(echo $MAIN_RES | cut -d'x' -f1)

    # Create virtual mode
    xrandr --newmode "1280x720_60.00"  74.50  1280 1344 1472 1664  720 723 728 748 -hsync +vsync 2>/dev/null

    # Add to HDMI-1 (or first disconnected output)
    DISCONNECTED=$(xrandr | grep disconnected | head -1 | cut -d' ' -f1)
    if [ -z "$DISCONNECTED" ]; then
        echo "Error: No disconnected output found!"
        exit 1
    fi
    xrandr --addmode $DISCONNECTED "1280x720_60.00" 2>/dev/null
    xrandr --output $DISCONNECTED --mode "1280x720_60.00" --right-of eDP-1
    if [ $? -ne 0 ]; then
        echo "Error: Failed to enable extended display!"
        exit 1
    fi

    echo "Extended display enabled on $DISCONNECTED"
    echo "Starting VNC server with cursor support..."
    echo "Connect your tablet to: $(hostname -I | awk '{print $1}'):5900"

    # Start VNC for extended area with proper cursor support
    x11vnc -display :0 -clip 1280x720+${MAIN_WIDTH}+0 -forever -nopw -shared \
      -cursor most -cursorpos -nocursorshape -nocursorpos -arrow 6 \
      -xwarppointer -buttonmap 123 -fixscreen V=3.0
}

# Stop extended display
stop_extended() {
    echo "Stopping extended display..."
    DISCONNECTED=$(xrandr | grep -E "(HDMI|VGA|VIRTUAL)" | grep " connected" | head -1 | cut -d' ' -f1)
    xrandr --output $DISCONNECTED --off 2>/dev/null
    pkill x11vnc
    echo "Extended display disabled"
}

# Show status
show_status() {
    echo "=== Linux Display Extend Status ==="
    if pgrep -f "x11vnc.*clip.*display-extend" > /dev/null; then
        echo "Extended display is running."
    else
        echo "Extended display is not running."
    fi
    echo "Configuration:"
    echo "  Resolution: ${DISPLAY_WIDTH}x${DISPLAY_HEIGHT}"
    echo "  Position: $DISPLAY_POSITION"
}

# Show VNC installation instructions
install_vnc_help() {
    echo "=== Install VNC Viewer on Android Display ==="
    echo "1. Download RealVNC Viewer (or similar) from Play Store."
    echo "2. Connect to the IP and port displayed when you run 'display-extend start'."
}

# Main script logic
case "$1" in
    start)
        start_extended
        ;;
    stop)
        stop_extended
        ;;
    status)
        load_config
        show_status
        ;;
    config)
        load_config
        configure
        ;;
    install-vnc)
        install_vnc_help
        ;;
    --help|-h|help|"")
        show_help
        ;;
    *)
        echo "Unknown command: $1"
        echo "Use 'display-extend --help' for usage information"
        exit 1
        ;;
esac
