#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
USER="${SUDO_USER:-$USER}"

echo "==> Installing kbd-backlight script to /usr/local/bin/"
install -m 755 "$SCRIPT_DIR/kbd-backlight" /usr/local/bin/kbd-backlight

echo "==> Installing udev rule to /etc/udev/rules.d/"
install -m 644 "$SCRIPT_DIR/90-kbd-backlight.rules" /etc/udev/rules.d/90-kbd-backlight.rules

echo "==> Adding $USER to 'input' group"
usermod -aG input "$USER"

echo "==> Reloading udev rules"
udevadm control --reload-rules
udevadm trigger --subsystem-match=leds

echo ""
echo "Done. Changes take effect:"
echo "  • Udev rule: immediately (backlight file is now group-writable)"
echo "  • Group membership: after next login"
echo ""
echo "To set backlight on login, add this line to ~/.profile:"
echo "  kbd-backlight set on"
echo ""
echo "Test now (without re-login) with:"
echo "  sudo kbd-backlight set on"
