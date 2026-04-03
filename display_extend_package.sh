#!/usr/bin/env bash

set -euo pipefail

APP_NAME="linux-display-extend"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VERSION="$(tr -d '[:space:]' < "$SCRIPT_DIR/VERSION")"
BUILD_ROOT="$SCRIPT_DIR/build/package"
PACKAGE_ROOT="$BUILD_ROOT/$APP_NAME-$VERSION"

rm -rf "$PACKAGE_ROOT"

mkdir -p "$PACKAGE_ROOT/DEBIAN" \
    "$PACKAGE_ROOT/usr/bin" \
    "$PACKAGE_ROOT/usr/local/share/$APP_NAME" \
    "$PACKAGE_ROOT/usr/share/applications" \
    "$PACKAGE_ROOT/usr/share/doc/$APP_NAME"

cat > "$PACKAGE_ROOT/DEBIAN/control" <<EOF
Package: $APP_NAME
Version: $VERSION
Section: utils
Priority: optional
Architecture: amd64
Depends: x11vnc, x11-xserver-utils, xserver-xorg-video-dummy
Maintainer: USKhokhar <contact.uskhokhar@gmail.com>
Homepage: https://github.com/USKhokhar/linux-display-extend
Vcs-Git: https://github.com/USKhokhar/linux-display-extend.git
Description: Use an Android device as an extended display for Linux X11
 A Bash-based X11 utility that uses xrandr and x11vnc to expose a real
 extended desktop region to an Android device over VNC.
EOF

install -m 755 "$SCRIPT_DIR/scripts/display-extend.sh" "$PACKAGE_ROOT/usr/bin/display-extend"
install -m 644 "$SCRIPT_DIR/VERSION" "$PACKAGE_ROOT/usr/local/share/$APP_NAME/VERSION"
install -m 644 "$SCRIPT_DIR/README.md" "$PACKAGE_ROOT/usr/share/doc/$APP_NAME/README.md"
install -m 644 "$SCRIPT_DIR/CHANGELOG.md" "$PACKAGE_ROOT/usr/share/doc/$APP_NAME/CHANGELOG.md"

cat > "$PACKAGE_ROOT/usr/share/applications/display-extend.desktop" <<EOF
[Desktop Entry]
Name=Linux Display Extend
Comment=Use an Android device as an extended display on X11
Exec=/usr/bin/display-extend
Icon=display
Terminal=true
Type=Application
Categories=System;Utility;
Keywords=display;extend;android;vnc;x11;
EOF

cat > "$PACKAGE_ROOT/DEBIAN/postinst" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

echo "Linux Display Extend installed."
echo "Run 'display-extend doctor' to validate your environment."
echo "Run 'display-extend start' to launch the extended display."
EOF

chmod +x "$PACKAGE_ROOT/DEBIAN/postinst"

printf 'Package tree prepared at: %s\n' "$PACKAGE_ROOT"
printf 'Build the .deb with:\n'
printf '  dpkg-deb --build "%s"\n' "$PACKAGE_ROOT"
