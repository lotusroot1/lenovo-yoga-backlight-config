#!/usr/bin/env bash
set -euo pipefail

# Also remove tray app if present (user-level, no sudo needed for those)
TRAY_BIN="$HOME/.local/bin/kbd-backlight-tray"
TRAY_DESKTOP="$HOME/.config/autostart/kbd-backlight-tray.desktop"
if [ -f "$TRAY_BIN" ] || [ -f "$TRAY_DESKTOP" ]; then
    echo "==> Removing tray app"
    pkill -f kbd-backlight-tray 2>/dev/null || true
    rm -f "$TRAY_BIN" "$TRAY_DESKTOP"
fi

echo "==> Stopping and disabling kbd-backlight service"
systemctl disable --now kbd-backlight.service 2>/dev/null || true
rm -f /etc/systemd/system/kbd-backlight.service
systemctl daemon-reload

echo "==> Removing acpi_call autoload"
rm -f /etc/modules-load.d/acpi_call.conf

echo "==> Removing sudo rule"
rm -f /etc/sudoers.d/kbd-backlight

echo "==> Removing kbd-backlight script"
rm -f /usr/local/bin/kbd-backlight

echo ""
echo "Done. acpi_call module is still loaded in the current session;"
echo "it will not reload on next boot."
echo ""
echo "To use native kernel backlight control once your kernel supports it:"
echo "  echo 2 > /sys/class/leds/platform::kbd_backlight/brightness  (on)"
echo "  echo 1 > /sys/class/leds/platform::kbd_backlight/brightness  (dim)"
echo "  echo 0 > /sys/class/leds/platform::kbd_backlight/brightness  (off)"
echo ""
echo "systemd-backlight will persist the value across reboots automatically."
