#!/usr/bin/env bash
# Installs the kbd-backlight tray app and adds it to the desktop autostart.
# Run as your normal user (not root) — only the dep-install step uses sudo.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_BIN="$HOME/.local/bin/kbd-backlight-tray"
AUTOSTART_DIR="$HOME/.config/autostart"
AUTOSTART_FILE="$AUTOSTART_DIR/kbd-backlight-tray.desktop"

# ── dependencies ──────────────────────────────────────────────────────────────
echo "==> Checking dependencies"

need_pkg=()
python3 -c "import gi" 2>/dev/null || need_pkg+=(python3-gi)

if ! python3 -c "
import gi
gi.require_version('AppIndicator3','0.1')
from gi.repository import AppIndicator3
" 2>/dev/null; then
    echo "    AppIndicator3 not found — installing for better Cinnamon tray support"
    need_pkg+=(gir1.2-appindicator3-0.1)
fi

if [ "${#need_pkg[@]}" -gt 0 ]; then
    sudo apt-get install -y "${need_pkg[@]}"
else
    echo "    All dependencies present"
fi

# ── install script ────────────────────────────────────────────────────────────
echo "==> Installing to $INSTALL_BIN"
mkdir -p "$HOME/.local/bin"
install -m 755 "$SCRIPT_DIR/kbd-backlight-tray" "$INSTALL_BIN"

# ── autostart entry ───────────────────────────────────────────────────────────
echo "==> Adding autostart entry"
mkdir -p "$AUTOSTART_DIR"
cat > "$AUTOSTART_FILE" <<EOF
[Desktop Entry]
Type=Application
Name=Keyboard Backlight Tray
Comment=System tray control for Yoga 9i Gen 7 keyboard backlight
Exec=$INSTALL_BIN
Icon=input-keyboard
StartupNotify=false
X-GNOME-Autostart-enabled=true
EOF

echo ""
echo "Done."
echo ""
echo "Launch now:   $INSTALL_BIN &"
echo "Autostart:    will run at next login"
echo ""
echo "To uninstall: ./uninstall.sh"
