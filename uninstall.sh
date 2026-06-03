#!/usr/bin/env bash
set -euo pipefail

# ── must match install.sh ────────────────────────────────────────────────────
KBD_BIN=/usr/local/bin/kbd-backlight
SERVICE_FILE=/etc/systemd/system/kbd-backlight.service
MODULES_CONF=/etc/modules-load.d/acpi_call.conf
SUDOERS_FILE=/etc/sudoers.d/kbd-backlight
# ─────────────────────────────────────────────────────────────────────────────

# Tray app (user-level — no sudo needed)
TRAY_BIN="$HOME/.local/bin/kbd-backlight-tray"
TRAY_DESKTOP="$HOME/.config/autostart/kbd-backlight-tray.desktop"
if [ -f "$TRAY_BIN" ] || [ -f "$TRAY_DESKTOP" ]; then
    echo "==> Removing tray app"
    pkill -f kbd-backlight-tray 2>/dev/null || true
    rm -f "$TRAY_BIN" "$TRAY_DESKTOP"
fi

echo "==> Stopping and disabling kbd-backlight service"
systemctl disable --now kbd-backlight.service 2>/dev/null || true
rm -f "$SERVICE_FILE"
systemctl daemon-reload

echo "==> Removing acpi_call autoload"
rm -f "$MODULES_CONF"

echo "==> Removing sudo rule"
rm -f "$SUDOERS_FILE"

echo "==> Removing kbd-backlight script"
rm -f "$KBD_BIN"

echo ""
echo "Done. acpi_call is still loaded this session; it will not reload on next boot."
echo ""
echo "When native kernel support lands, use sysfs directly:"
echo "  echo 2 > /sys/class/leds/platform::kbd_backlight/brightness  (on)"
echo "  echo 1 > /sys/class/leds/platform::kbd_backlight/brightness  (dim)"
echo "  echo 0 > /sys/class/leds/platform::kbd_backlight/brightness  (off)"
echo "systemd-backlight persists the value across reboots automatically."
