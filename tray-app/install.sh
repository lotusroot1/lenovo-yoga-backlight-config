#!/usr/bin/env bash
# Installs the kbd-backlight tray app and adds it to the desktop autostart.
# Run as your normal user (not root).
#
# PREREQUISITE: the root install.sh in the repo root must be run first:
#   sudo ../install.sh
set -euo pipefail

# ── must match root install.sh ───────────────────────────────────────────────
KBD_BIN=/usr/local/bin/kbd-backlight
SUDOERS_FILE=/etc/sudoers.d/kbd-backlight
MODULES_CONF=/etc/modules-load.d/acpi_call.conf
# ─────────────────────────────────────────────────────────────────────────────

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
INSTALL_BIN="$HOME/.local/bin/kbd-backlight-tray"
AUTOSTART_FILE="$HOME/.config/autostart/kbd-backlight-tray.desktop"

# ── check root install was done first ────────────────────────────────────────
echo "==> Checking prerequisites"
missing=()
[ -f "$KBD_BIN" ]        || missing+=("kbd-backlight script ($KBD_BIN)")
[ -f "$SUDOERS_FILE" ]   || missing+=("sudoers rule ($SUDOERS_FILE)")
[ -f "$MODULES_CONF" ]   || missing+=("acpi_call autoload ($MODULES_CONF)")

if [ "${#missing[@]}" -gt 0 ]; then
    echo ""
    echo "ERROR: root install is incomplete. Missing:"
    for m in "${missing[@]}"; do echo "  • $m"; done
    echo ""
    echo "Run first:  cd '$REPO_ROOT' && sudo ./install.sh"
    exit 1
fi
echo "    Prerequisites OK"

# ── Python / GTK dependencies ─────────────────────────────────────────────────
echo "==> Checking Python/GTK dependencies"

if ! python3 -c "import gi" 2>/dev/null; then
    echo "ERROR: python3-gi not found."
    echo "  Debian/Ubuntu:  sudo apt install python3-gi"
    echo "  Fedora:         sudo dnf install python3-gobject"
    echo "  Arch:           sudo pacman -S python-gobject"
    exit 1
fi

if ! python3 -c "
import gi
gi.require_version('AppIndicator3','0.1')
from gi.repository import AppIndicator3
" 2>/dev/null; then
    echo "    AppIndicator3 not found — tray will fall back to Gtk.StatusIcon"
    echo "    For better Cinnamon integration, install it:"
    echo "      Debian/Ubuntu:  sudo apt install gir1.2-appindicator3-0.1"
    echo "      Fedora:         sudo dnf install libappindicator-gtk3"
    echo "    (continuing without it)"
fi

# ── install ───────────────────────────────────────────────────────────────────
echo "==> Installing to $INSTALL_BIN"
mkdir -p "$HOME/.local/bin"
install -m 755 "$SCRIPT_DIR/kbd-backlight-tray" "$INSTALL_BIN"

echo "==> Adding autostart entry"
mkdir -p "$(dirname "$AUTOSTART_FILE")"
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
echo "  Launch now:   $INSTALL_BIN &"
echo "  Autostart:    active at next login"
echo "  Uninstall:    ./uninstall.sh  (or sudo ../uninstall.sh for everything)"
