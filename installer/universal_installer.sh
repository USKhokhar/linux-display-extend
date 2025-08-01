#!/bin/bash
# Linux Display Extend - Universal Installer
# Author: USKhokhar (https://github.com/USKhokhar)
# Email: contact.uskhokhar@gmail.com
# Twitter: https://twitter.com/US_Khokhar
# Portfolio: https://uskhokhar.vercel.app
# Repository: https://github.com/USKhokhar/linux-display-extend
# Works on Ubuntu, Debian, Fedora, Arch, openSUSE

set -e

INSTALL_DIR="/usr/local/bin"
CONFIG_DIR="$HOME/.config/linux-display-extend"
REPO_URL="https://github.com/USKhokhar/linux-display-extend"
VERSION="1.0"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Detect Linux distribution
detect_distro() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        DISTRO=$ID
        VERSION_ID=$VERSION_ID
    else
        print_error "Cannot detect Linux distribution"
        exit 1
    fi
}

# Install dependencies based on distribution
install_dependencies() {
    print_status "Installing dependencies for $DISTRO..."
    
    case $DISTRO in
        "ubuntu"|"debian"|"linuxmint"|"pop"|"elementary")
            sudo apt update
            sudo apt install -y x11vnc xserver-xorg-video-dummy curl
            ;;
        "fedora")
            sudo dnf install -y x11vnc xorg-x11-drv-dummy curl
            ;;
        "centos"|"rhel"|"rocky"|"almalinux")
            sudo yum install -y epel-release
            sudo yum install -y x11vnc xorg-x11-drv-dummy curl
            ;;
        "arch"|"manjaro"|"endeavouros")
            sudo pacman -S --noconfirm x11vnc xf86-video-dummy curl
            ;;
        "opensuse"|"opensuse-leap"|"opensuse-tumbleweed")
            sudo zypper install -y x11vnc xf86-video-dummy curl
            ;;
        *)
            print_warning "Unsupported distribution: $DISTRO"
            print_status "Please install these packages manually:"
            echo "  - x11vnc"
            echo "  - xserver video dummy driver"
            read -p "Continue anyway? (y/N): " -n 1 -r
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                exit 1
            fi
            ;;
    esac
}

# Download and install main script
install_display_extend() {
    print_status "Installing Linux Display Extend..."
    
    # Copy main script from modular source
    sudo install -m 755 "$(dirname "$0")/../scripts/display-extend.sh" "$INSTALL_DIR/display-extend"

    # Create config directory
    mkdir -p "$CONFIG_DIR"

    # Create default config
    if [[ ! -f "$CONFIG_DIR/config" ]]; then
        cat > "$CONFIG_DIR/config" << 'CONFIG_EOF'
# Linux Display Extend Configuration
DISPLAY_WIDTH=1280
DISPLAY_HEIGHT=720
DISPLAY_POSITION=right
CONFIG_EOF
    fi
}

# Create desktop entry
create_desktop_entry() {
    DESKTOP_DIR="$HOME/.local/share/applications"
    mkdir -p "$DESKTOP_DIR"
    
    cat > "$DESKTOP_DIR/display-extend.desktop" << 'DESKTOP_EOF'
[Desktop Entry]
Name=Display Extend
Comment=Use Android display as extended display
Exec=display-extend
Icon=display
Terminal=true
Type=Application
Categories=System;Utility;
Keywords=display;display;extend;vnc;android;
DESKTOP_EOF
    
    print_status "Desktop entry created"
}

# Create uninstaller
create_uninstaller() {
    sudo tee "/usr/local/bin/display-extend-uninstall" > /dev/null << 'UNINSTALL_EOF'
#!/bin/bash
echo "Uninstalling Linux Display Extend..."

# Stop any running instances
display-extend stop 2>/dev/null || true

# Remove files
sudo rm -f /usr/local/bin/display-extend
sudo rm -f /usr/local/bin/display-extend-uninstall
rm -f "$HOME/.local/share/applications/display-extend.desktop"

# Ask about config
read -p "Remove configuration files? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    rm -rf "$HOME/.config/linux-display-extend"
    echo "Configuration removed"
fi

echo "Linux Display Extend uninstalled successfully!"
UNINSTALL_EOF

    sudo chmod +x "/usr/local/bin/display-extend-uninstall"
}

# Main installation flow
main() {
    echo -e "${BLUE}"
    echo "Linux Display Extend Installer"
    echo
    # Check if running as root
    if [[ $EUID -eq 0 ]]; then
        print_error "Please don't run this installer as root"
        print_status "Run as regular user (installer will ask for sudo when needed)"
        exit 1
    fi
    
    # Check for sudo access
    print_status "Checking sudo access..."
    if ! sudo -n true 2>/dev/null; then
        print_status "This installer requires sudo access for installing dependencies"
        sudo true
    fi
    
    detect_distro
    print_status "Detected distribution: $DISTRO"
    
    # Install dependencies
    install_dependencies
    
    # Install main application
    install_display_extend
    
    # Create desktop entry
    create_desktop_entry
    
    # Create uninstaller
    create_uninstaller
    
    print_status "Installation completed successfully!"
    echo
    echo -e "${GREEN}Quick Start:${NC}"
    echo "  1. Run: ${BLUE}display-extend start${NC}"
    echo "  2. Install VNC Viewer on your Android display"
    echo "  3. Connect to the IP address shown"
    echo
    echo -e "${GREEN}Available commands:${NC}"
    echo "  ${BLUE}display-extend start${NC}       - Start extended display"
    echo "  ${BLUE}display-extend stop${NC}        - Stop extended display"
    echo "  ${BLUE}display-extend config${NC}      - Configure settings"
    echo "  ${BLUE}display-extend status${NC}      - Show current status"
    echo "  ${BLUE}display-extend --help${NC}      - Show all commands"
    echo
    echo -e "${GREEN}To uninstall:${NC} ${BLUE}display-extend-uninstall${NC}"
    echo
    echo -e "${YELLOW}Star us on GitHub:${NC} $REPO_URL"
}

# Handle command line arguments
case "${1:-}" in
    "--help"|"-h")
        echo "Linux Display Extend Installer"
        echo "Usage: $0 [--help]"
        echo
        echo "This script will install Linux Display Extend and its dependencies"
        echo "on your system. It supports most major Linux distributions."
        exit 0
        ;;
    *)
        main "$@"
        ;;
esac
