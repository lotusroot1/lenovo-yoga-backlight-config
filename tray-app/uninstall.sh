#!/usr/bin/env bash
set -euo pipefail

echo "==> Removing tray app"
rm -f "$HOME/.local/bin/kbd-backlight-tray"

echo "==> Removing autostart entry"
rm -f "$HOME/.config/autostart/kbd-backlight-tray.desktop"

echo "==> Killing any running instance"
pkill -f kbd-backlight-tray 2>/dev/null || true

echo "Done."
