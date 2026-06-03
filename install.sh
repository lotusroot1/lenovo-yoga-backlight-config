#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
USER="${SUDO_USER:-$USER}"
STARTUP_STATE="${1:-auto}"

case "$STARTUP_STATE" in
    off|dim|on|auto) ;;
    *) echo "ERROR: invalid state '$STARTUP_STATE' — use: off, dim, on, auto" >&2; exit 1 ;;
esac

echo "==> Installing kbd-backlight to /usr/local/bin/"
install -m 755 "$SCRIPT_DIR/kbd-backlight" /usr/local/bin/kbd-backlight

echo "==> Configuring acpi_call to load at boot"
echo "acpi_call" > /etc/modules-load.d/acpi_call.conf

echo "==> Installing systemd service (startup state: $STARTUP_STATE)"
cat > /etc/systemd/system/kbd-backlight.service <<EOF
[Unit]
Description=Set keyboard backlight state on boot
After=systemd-modules-load.service

[Service]
Type=oneshot
ExecStartPre=/sbin/modprobe acpi_call
ExecStart=/usr/local/bin/kbd-backlight set $STARTUP_STATE
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable kbd-backlight.service

echo "==> Adding passwordless sudo rule for kbd-backlight"
echo "$USER ALL=(ALL) NOPASSWD: /usr/local/bin/kbd-backlight" \
    > /etc/sudoers.d/kbd-backlight
chmod 440 /etc/sudoers.d/kbd-backlight

echo ""
echo "Done. Startup state set to: $STARTUP_STATE"
echo ""
echo "Usage (no password needed):"
echo "  sudo kbd-backlight get"
echo "  sudo kbd-backlight set auto"
echo "  sudo kbd-backlight set on"
echo "  sudo kbd-backlight set dim"
echo "  sudo kbd-backlight set off"
echo ""
echo "To change the startup state, re-run:"
echo "  sudo ./install.sh <state>"
echo "(e.g. sudo ./install.sh on)"
