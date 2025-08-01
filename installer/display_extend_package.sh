#!/bin/bash
# Linux Display Extend - Package Creation Script
# Author: USKhokhar (https://github.com/USKhokhar)
# Email: contact.uskhokhar@gmail.com
# Twitter: https://twitter.com/US_Khokhar
# Portfolio: https://uskhokhar.vercel.app
# Repository: https://github.com/USKhokhar/linux-display-extend

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
Maintainer: USKhokhar <contact.uskhokhar@gmail.com>
Homepage: https://github.com/USKhokhar/linux-display-extend
Vcs-Git: https://github.com/USKhokhar/linux-display-extend.git
Description: Use Android display as extended display for Linux
 A simple tool to use your Android display as an extended display
 for your Linux desktop, similar to Windows/Mac extended desktop functionality.
 Supports mouse movement and window dragging between displays.
EOF

# Copy main executable script from modular source
cp "$(dirname "$0")/../scripts/display-extend.sh" linux-display-extend-1.0/usr/bin/display-extend

# Make executable
chmod +x linux-display-extend-1.0/usr/bin/display-extend

# Create desktop entry
cat > linux-display-extend-1.0/usr/share/applications/display-extend.desktop << 'EOF'
[Desktop Entry]
Name=Display Extend
Comment=Use Android display as extended display
Exec=display-extend
Icon=display
Terminal=true
Type=Application
Categories=System;Utility;
Keywords=display;display;extend;vnc;android;
EOF

# Create documentation
cat > linux-display-extend-1.0/usr/share/doc/linux-display-extend/README << 'EOF'
Linux Display Extend
==================

Use your Android display as an extended display for your Linux desktop.

Features:
- True extended desktop (not mirroring)
- Mouse movement between displays
- Drag windows between laptop and display
- Configurable resolution and positioning
- Easy setup with single command

Quick Start:
1. Install the package
2. Run: display-extend start
3. Install VNC Viewer on your Android display
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
echo "Don't forget to install VNC Viewer on your Android display!"
EOF

chmod +x linux-display-extend-1.0/DEBIAN/postinst

echo "Package structure created!"
echo "To build the .deb package, run:"
echo "  dpkg-deb --build linux-display-extend-1.0"
echo ""
echo "To install locally:"
echo "  sudo dpkg -i linux-display-extend-1.0.deb"
