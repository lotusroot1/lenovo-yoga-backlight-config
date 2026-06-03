#!/usr/bin/env bash
set -euo pipefail

# ── install locations (change here to relocate everything) ───────────────────
KBD_BIN=/usr/local/bin/kbd-backlight
SERVICE_FILE=/etc/systemd/system/kbd-backlight.service
MODULES_CONF=/etc/modules-load.d/acpi_call.conf
SUDOERS_FILE=/etc/sudoers.d/kbd-backlight
# ─────────────────────────────────────────────────────────────────────────────

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_USER="${SUDO_USER:-$USER}"
STARTUP_STATE="${1:-auto}"

case "$STARTUP_STATE" in
    off|dim|on|auto) ;;
    *) echo "ERROR: invalid state '$STARTUP_STATE' — use: off, dim, on, auto" >&2; exit 1 ;;
esac

echo "==> Installing kbd-backlight to $KBD_BIN"
install -m 755 "$SCRIPT_DIR/kbd-backlight" "$KBD_BIN"

echo "==> Configuring acpi_call to load at boot"
echo "acpi_call" > "$MODULES_CONF"

echo "==> Installing systemd service (startup state: $STARTUP_STATE)"
cat > "$SERVICE_FILE" <<EOF
[Unit]
Description=Set keyboard backlight state on boot
After=systemd-modules-load.service

[Service]
Type=oneshot
ExecStartPre=modprobe acpi_call
ExecStart=$KBD_BIN set $STARTUP_STATE
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable kbd-backlight.service

echo "==> Adding passwordless sudo rule for kbd-backlight"
echo "$INSTALL_USER ALL=(ALL) NOPASSWD: $KBD_BIN" > "$SUDOERS_FILE"
chmod 440 "$SUDOERS_FILE"

echo ""
echo "Done. Startup state: $STARTUP_STATE"
echo ""
echo "Usage (no password needed):"
echo "  sudo kbd-backlight get"
echo "  sudo kbd-backlight set auto"
echo ""
echo "To change the startup state: sudo ./install.sh <state>"
