#!/bin/bash
# Linux Display Extend - Main Script (modular source)
# Author: USKhokhar (https://github.com/USKhokhar)
# Email: contact.uskhokhar@gmail.com
# Twitter: https://twitter.com/US_Khokhar
# Portfolio: https://uskhokhar.vercel.app
# Repository: https://github.com/USKhokhar/linux-display-extend


VERSION="1.1.0"
LATEST_VERSION_URL="https://raw.githubusercontent.com/USKhokhar/linux-display-extend/main/VERSION"
SCRIPT_DIR="/usr/share/linux-display-extend"
CONFIG_DIR="$HOME/.config/linux-display-extend"
CONFIG_FILE="$CONFIG_DIR/config"

# Create config directory if it doesn't exist
mkdir -p "$CONFIG_DIR"

# Default configuration
DEFAULT_WIDTH="1280"
DEFAULT_HEIGHT="720"
DEFAULT_POSITION="right"
DEFAULT_MAIN_MONITOR="eDP-1"

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
MAIN_MONITOR=$DEFAULT_MAIN_MONITOR
CONF
        source "$CONFIG_FILE"
    fi
    
    DISPLAY_WIDTH=${DISPLAY_WIDTH:-$DEFAULT_WIDTH}
    DISPLAY_HEIGHT=${DISPLAY_HEIGHT:-$DEFAULT_HEIGHT}
    DISPLAY_POSITION=${DISPLAY_POSITION:-$DEFAULT_POSITION}
    MAIN_MONITOR=${MAIN_MONITOR:-$DEFAULT_MAIN_MONITOR}
}

check_for_updates() {
    if ! command -v curl &> /dev/null; then
        return
    fi
    
    current_version=$VERSION
    latest_version=$(curl -s $LATEST_VERSION_URL 2>/dev/null || echo $VERSION)
    
    if [ "$current_version" != "$latest_version" ]; then
        echo " New version available: $latest_version (you have $current_version)"
        echo "   Run 'display-extend update' to update to the latest version"
        echo "   Changelog: https://github.com/USKhokhar/linux-display-extend/blob/main/CHANGELOG.md"
        echo ""
    fi
}

# Show help
show_help() {
    echo "Linux Display Extend v$VERSION"
    echo "Use your Android device as a true extended display for Linux"
    echo ""
    echo "Usage: display-extend [command]"
    echo ""
    echo "Commands:"
    echo "  start               - Start the extended display"
    echo "  stop                - Stop the extended display"
    echo "  restart             - Restart the extended display"
    echo "  status              - Show current status"
    echo "  config              - Configure display settings"
    echo "  install-vnc         - Show VNC installation instructions"
    echo "  update              - Update to the latest version"
    echo "  --help, -h          - Show this help message"
    echo "  --version, -v       - Show version information"
    echo ""
    echo "Configuration: $CONFIG_FILE"
    echo "Issues: https://github.com/USKhokhar/linux-display-extend/issues"
    echo ""
    check_for_updates
}

update_self() {
    echo "Updating Linux Display Extend..."
    
    if ! command -v curl &> /dev/null; then
        echo "Error: curl is required to update"
        exit 1
    fi
    
    echo "Downloading the latest version..."
    temp_file=$(mktemp)
    if curl -sSL https://raw.githubusercontent.com/USKhokhar/linux-display-extend/main/installer/universal_installer.sh -o "$temp_file"; then
        chmod +x "$temp_file"
        echo "Installing update..."
        exec "$temp_file"
    else
        echo "Failed to download update"
        rm -f "$temp_file"
        exit 1
    fi
}

show_version() {
    echo "Linux Display Extend v$VERSION"
    echo "https://github.com/USKhokhar/linux-display-extend"
    check_for_updates
}

# Interactive configuration
configure() {
    echo "=== Linux Display Extend Configuration ==="
    echo ""
    echo "Current settings:"
    echo "  Resolution: ${DISPLAY_WIDTH}x${DISPLAY_HEIGHT}"
    echo "  Position: $DISPLAY_POSITION of main display"
    echo "  Main Monitor: $MAIN_MONITOR"
    echo ""
    
    read -p "Enter display resolution width (default: $DISPLAY_WIDTH): " width
    read -p "Enter display resolution height (default: $DISPLAY_HEIGHT): " height
    read -p "Position relative to main display [left/right/above/below] (default: $DISPLAY_POSITION): " position
    read -p "Main Monitor (default: $MAIN_MONITOR): " main_monitor
    
    # Use defaults if empty
    width=${width:-$DISPLAY_WIDTH}
    height=${height:-$DISPLAY_HEIGHT}
    position=${position:-$DISPLAY_POSITION}
    main_monitor=${main_monitor:-$MAIN_MONITOR}
    
    # Update config file
    cat > "$CONFIG_FILE" << CONF
# Linux Display Extend Configuration
DISPLAY_WIDTH=$width
DISPLAY_HEIGHT=$height
DISPLAY_POSITION=$position
MAIN_MONITOR=$main_monitor
CONF
    
    echo "Configuration saved to $CONFIG_FILE"
    DISPLAY_WIDTH=$width
    DISPLAY_HEIGHT=$height
    DISPLAY_POSITION=$position
    MAIN_MONITOR=$main_monitor
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

    # Load configuration
    load_config

    # Get your laptop's main resolution first
    MAIN_RES=$(xrandr | grep "$MAIN_MONITOR" | grep -o "[0-9]*x[0-9]*" | head -1)
    if [ -z "$MAIN_RES" ]; then
        echo "Error: Could not find resolution for monitor $MAIN_MONITOR"
        echo "Available monitors: $(xrandr | grep " connected" | cut -d' ' -f1 | tr '\n' ' ')"
        exit 1
    fi
    MAIN_WIDTH=$(echo $MAIN_RES | cut -d'x' -f1)

    # Create virtual mode
    xrandr --newmode "1280x720_60.00"  74.50  1280 1344 1472 1664  720 723 728 748 -hsync +vsync 2>/dev/null

    # Add to first disconnected output
    DISCONNECTED=$(xrandr | grep disconnected | head -1 | cut -d' ' -f1)
    if [ -z "$DISCONNECTED" ]; then
        echo "Error: No disconnected output found!"
        exit 1
    fi
    xrandr --addmode $DISCONNECTED "1280x720_60.00" 2>/dev/null
    xrandr --output $DISCONNECTED --mode "1280x720_60.00" --${DISPLAY_POSITION:-right}-of $MAIN_MONITOR
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
    echo "  Main Monitor: $MAIN_MONITOR"
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
        load_config
        start_extended
        ;;
    stop)
        stop_extended
        ;;
    restart)
        stop_extended
        sleep 1
        load_config
        start_extended
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
    update)
        update_self
        ;;
    --version|-v)
        show_version
        ;;
    --help|-h|*)
        show_help
        ;;
esac
