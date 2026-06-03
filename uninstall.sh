#!/usr/bin/env bash
set -euo pipefail

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
