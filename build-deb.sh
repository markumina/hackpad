#!/usr/bin/env bash
set -euo pipefail

PACKAGE="hackpad"
VERSION="${VERSION:-0.1.0}"
ARCHITECTURE="all"

REPO_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
BUILD_DIR="$(mktemp -d "${TMPDIR:-/tmp}/${PACKAGE}-deb.XXXXXX")"
OUT_DIR="${REPO_DIR}/dist"
OUT_FILE="${OUT_DIR}/${PACKAGE}_${VERSION}_${ARCHITECTURE}.deb"

cleanup() {
    rm -rf "$BUILD_DIR"
}
trap cleanup EXIT

mkdir -p \
    "$BUILD_DIR/DEBIAN" \
    "$BUILD_DIR/opt/hackpad" \
    "$BUILD_DIR/etc/systemd/system" \
    "$BUILD_DIR/usr/share/doc/hackpad" \
    "$OUT_DIR"

install -m 0755 "$REPO_DIR/hackpad.sh" "$BUILD_DIR/opt/hackpad/hackpad.sh"
install -m 0644 "$REPO_DIR/hackpad.service" "$BUILD_DIR/etc/systemd/system/hackpad.service"
install -m 0644 "$REPO_DIR/README.md" "$BUILD_DIR/usr/share/doc/hackpad/README.md"

cat > "$BUILD_DIR/DEBIAN/control" <<EOF
Package: ${PACKAGE}
Version: ${VERSION}
Section: utils
Priority: optional
Architecture: ${ARCHITECTURE}
Depends: bash, libinput-tools, systemd
Maintainer: Mark Umina <mark.umina@gmail.com>
Description: Touchpad inhibition helper for typing on Wayland
 Hackpad temporarily inhibits the touchpad after keyboard input so palm taps
 do not become accidental clicks while typing.
EOF

cat > "$BUILD_DIR/DEBIAN/conffiles" <<EOF
/etc/systemd/system/hackpad.service
EOF

cat > "$BUILD_DIR/DEBIAN/postinst" <<'EOF'
#!/bin/sh
set -e

if command -v systemctl >/dev/null 2>&1; then
    systemctl daemon-reload || true
    systemctl enable hackpad.service || true
    systemctl restart hackpad.service || true
fi

exit 0
EOF

cat > "$BUILD_DIR/DEBIAN/prerm" <<'EOF'
#!/bin/sh
set -e

if [ "$1" = "remove" ] || [ "$1" = "deconfigure" ]; then
    if command -v systemctl >/dev/null 2>&1; then
        systemctl stop hackpad.service || true
        systemctl disable hackpad.service || true
    fi
fi

exit 0
EOF

cat > "$BUILD_DIR/DEBIAN/postrm" <<'EOF'
#!/bin/sh
set -e

if command -v systemctl >/dev/null 2>&1; then
    systemctl daemon-reload || true
fi

exit 0
EOF

chmod 0755 \
    "$BUILD_DIR/DEBIAN/postinst" \
    "$BUILD_DIR/DEBIAN/prerm" \
    "$BUILD_DIR/DEBIAN/postrm"

find "$BUILD_DIR" -type d -exec chmod 0755 {} +

dpkg-deb --build --root-owner-group "$BUILD_DIR" "$OUT_FILE"
echo "$OUT_FILE"
