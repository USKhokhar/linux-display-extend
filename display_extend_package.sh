#!/bin/bash
# Linux Display Extend - Package Creation Script

# Create package directory structure
mkdir -p linux-display-extend-1.0/{DEBIAN,usr/bin,usr/share/applications,usr/share/doc/linux-display-extend,etc/linux-display-extend}

# Create DEBIAN control file
cat > linux-display-extend-1.0/DEBIAN/control << 'EOF'
Package: linux-display-extend
Version: 1.0
Section: utils
Priority: optional
Architecture: amd64
Depends: x11vnc, xserver-xorg-video-dummy
Maintainer: Your Name <your.email@example.com>
Description: Use Android tablet as extended display for Linux
 A simple tool to use your Android tablet as an extended display
 for your Linux desktop, similar to Windows/Mac extended desktop functionality.
 Supports mouse movement and window dragging between displays.
EOF

# Create main executable script
cat > linux-display-extend-1.0/usr/bin/display-extend << 'EOF'
#!/bin/bash

# Linux Display Extend - Main Script
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
    echo "Use your Android tablet as an extended display"
    echo ""
    echo "Usage:"
    echo "  display-extend start                 - Start extended display"
    echo "  display-extend stop                  - Stop extended display"
    echo "  display-extend status                - Show current status"
    echo "  display-extend config                - Configure display settings"
    echo "  display-extend install-vnc           - Install VNC viewer on tablet"
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
    
    read -p "Enter tablet resolution width (default: $DISPLAY_WIDTH): " width
    read -p "Enter tablet resolution height (default: $DISPLAY_HEIGHT): " height
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
    echo "Starting Linux Display Extend..."
    
    # Check if already running
    if pgrep -f "x11vnc.*clip.*display-extend" > /dev/null; then
        echo "Extended display is already running!"
        echo "Use 'display-extend stop' to stop it first."
        exit 1
    fi
    
    get_main_display
    load_config
    
    # Calculate position offset
    case $DISPLAY_POSITION in
        "right")
            OFFSET_X=$MAIN_WIDTH
            OFFSET_Y=0
            XRANDR_POS="--right-of"
            ;;
        "left") 
            OFFSET_X=0
            OFFSET_Y=0
            XRANDR_POS="--left-of"
            ;;
        "above")
            OFFSET_X=0
            OFFSET_Y=0
            XRANDR_POS="--above"
            ;;
        "below")
            OFFSET_X=0
            OFFSET_Y=$MAIN_HEIGHT
            XRANDR_POS="--below"
            ;;
        *)
            OFFSET_X=$MAIN_WIDTH
            OFFSET_Y=0
            XRANDR_POS="--right-of"
            ;;
    esac
    
    # Create modeline
    MODELINE=$(cvt $DISPLAY_WIDTH $DISPLAY_HEIGHT 60 | grep "Modeline" | cut -d' ' -f2-)
    MODE_NAME=$(echo $MODELINE | cut -d' ' -f1 | tr -d '"')
    
    echo "Setting up ${DISPLAY_WIDTH}x${DISPLAY_HEIGHT} extended display..."
    
    # Add virtual display
    xrandr --newmode $MODELINE 2>/dev/null
    
    # Find disconnected output
    DISCONNECTED=$(xrandr | grep disconnected | head -1 | cut -d' ' -f1)
    if [[ -z "$DISCONNECTED" ]]; then
        echo "Error: No disconnected display output found!"
        echo "Available outputs:"
        xrandr | grep -E "(connected|disconnected)"
        exit 1
    fi
    
    # Configure extended display
    xrandr --addmode $DISCONNECTED "$MODE_NAME" 2>/dev/null
    xrandr --output $DISCONNECTED --mode "$MODE_NAME" $XRANDR_POS $MAIN_DISPLAY
    
    if [[ $? -ne 0 ]]; then
        echo "Error: Failed to enable extended display!"
        exit 1
    fi
    
    echo "Extended display enabled on $DISCONNECTED"
    echo ""
    
    # Get IP address
    IP_ADDR=$(hostname -I | awk '{print $1}')
    
    echo "=== Connection Info ==="
    echo "Tablet VNC connection: $IP_ADDR:5900"
    echo "Extended display: ${DISPLAY_WIDTH}x${DISPLAY_HEIGHT} $DISPLAY_POSITION of main display"
    echo ""
    echo "Starting VNC server..."
    
    # Start VNC server with proper cursor support
    x11vnc -display :0 -clip ${DISPLAY_WIDTH}x${DISPLAY_HEIGHT}+${OFFSET_X}+${OFFSET_Y} \
           -forever -nopw -shared -cursor most -cursorpos -xwarppointer -arrow 6 \
           -rfbport 5900 -desktop "TabletExtend-$USER" &
    
    VNC_PID=$!
    echo $VNC_PID > "$CONFIG_DIR/vnc.pid"
    echo $DISCONNECTED > "$CONFIG_DIR/display.name"
    
    echo ""
    echo "✓ Extended display is ready!"
    echo ""
    echo "Next steps:"
    echo "1. Install VNC Viewer on your Android tablet"
    echo "2. Connect to: $IP_ADDR:5900"
    echo "3. Move your mouse to the edge of your screen to access the tablet"
    echo ""
    echo "Use 'display-extend stop' to disable the extended display"
}

# Stop extended display
stop_extended() {
    echo "Stopping extended display..."
    
    # Kill VNC server
    if [[ -f "$CONFIG_DIR/vnc.pid" ]]; then
        VNC_PID=$(cat "$CONFIG_DIR/vnc.pid")
        if ps -p $VNC_PID > /dev/null 2>&1; then
            kill $VNC_PID
            echo "VNC server stopped"
        fi
        rm -f "$CONFIG_DIR/vnc.pid"
    else
        pkill -f "x11vnc.*clip.*"
    fi
    
    # Disable virtual display
    if [[ -f "$CONFIG_DIR/display.name" ]]; then
        DISPLAY_NAME=$(cat "$CONFIG_DIR/display.name")
        xrandr --output $DISPLAY_NAME --off 2>/dev/null
        rm -f "$CONFIG_DIR/display.name"
        echo "Virtual display $DISPLAY_NAME disabled"
    fi
    
    echo "✓ Extended display stopped"
}

# Show status
show_status() {
    echo "=== Linux Display Extend Status ==="
    
    if pgrep -f "x11vnc.*clip" > /dev/null; then
        echo "Status: ✓ RUNNING"
        
        # Get VNC info
        VNC_PROC=$(pgrep -f "x11vnc.*clip")
        IP_ADDR=$(hostname -I | awk '{print $1}')
        echo "VNC Server: Active (PID: $VNC_PROC)"
        echo "Connection: $IP_ADDR:5900"
        
        # Get virtual display info
        VIRTUAL_DISPLAY=$(xrandr | grep -E "(HDMI|VGA|VIRTUAL)" | grep " connected" | head -1)
        if [[ -n "$VIRTUAL_DISPLAY" ]]; then
            echo "Virtual Display: $VIRTUAL_DISPLAY"
        fi
    else
        echo "Status: ✗ STOPPED"
    fi
    
    load_config
    echo ""
    echo "Configuration:"
    echo "  Resolution: ${DISPLAY_WIDTH}x${DISPLAY_HEIGHT}"
    echo "  Position: $DISPLAY_POSITION"
    echo "  Config file: $CONFIG_FILE"
}

# Show VNC installation instructions
install_vnc_help() {
    echo "=== Install VNC Viewer on Android Tablet ==="
    echo ""
    echo "1. Open Google Play Store on your tablet"
    echo "2. Search for 'VNC Viewer'"
    echo "3. Install 'VNC Viewer' by RealVNC"
    echo "4. Open the app and tap '+' to add connection"
    echo "5. Enter your laptop's IP address: $(hostname -I | awk '{print $1}')"
    echo "6. Port: 5900 (default)"
    echo "7. Name: 'Linux Extended Display'"
    echo ""
    echo "Alternative VNC apps:"
    echo "- RVNC (Real VNC client)"
    echo "- VNC Viewer Plus"
    echo "- MultiVNC"
    echo ""
    echo "After installation, use 'display-extend start' to begin"
}

# Main script logic
case "$1" in
    "start")
        start_extended
        ;;
    "stop")
        stop_extended
        ;;
    "status")
        show_status
        ;;
    "config")
        configure
        ;;
    "install-vnc")
        install_vnc_help
        ;;
    "--help"|"-h"|"help"|"")
        show_help
        ;;
    *)
        echo "Unknown command: $1"
        echo "Use 'display-extend --help' for usage information"
        exit 1
        ;;
esac
EOF

# Make executable
chmod +x linux-display-extend-1.0/usr/bin/display-extend

# Create desktop entry
cat > linux-display-extend-1.0/usr/share/applications/display-extend.desktop << 'EOF'
[Desktop Entry]
Name=Tablet Extend
Comment=Use Android tablet as extended display
Exec=display-extend
Icon=display
Terminal=true
Type=Application
Categories=System;Utility;
Keywords=tablet;display;extend;vnc;android;
EOF

# Create documentation
cat > linux-display-extend-1.0/usr/share/doc/linux-display-extend/README << 'EOF'
Linux Display Extend
==================

Use your Android tablet as an extended display for your Linux desktop.

Features:
- True extended desktop (not mirroring)
- Mouse movement between displays
- Drag windows between laptop and tablet
- Configurable resolution and positioning
- Easy setup with single command

Quick Start:
1. Install the package
2. Run: display-extend start
3. Install VNC Viewer on your Android tablet
4. Connect to the displayed IP address

For more information, run: display-extend --help
EOF

# Create postinst script for dependencies
cat > linux-display-extend-1.0/DEBIAN/postinst << 'EOF'
#!/bin/bash
echo "Linux Display Extend installed successfully!"
echo ""
echo "Quick start:"
echo "  display-extend start    # Start extended display"
echo "  display-extend --help   # Show all commands"
echo ""
echo "Don't forget to install VNC Viewer on your Android tablet!"
EOF

chmod +x linux-display-extend-1.0/DEBIAN/postinst

echo "Package structure created!"
echo "To build the .deb package, run:"
echo "  dpkg-deb --build linux-display-extend-1.0"
echo ""
echo "To install locally:"
echo "  sudo dpkg -i linux-display-extend-1.0.deb"