# Lenovo Yoga 9i Gen 7 — Keyboard Backlight Research Notes

Investigation into programmatically reading and setting keyboard backlight
state on Lenovo Yoga 9i Gen 7 (14IAP7) running Linux Mint.

---

## Result

All 4 firmware states (off / dim / on / auto) can be read and set by calling
the ACPI `KBLC` method directly via the `acpi_call` kernel module.

```bash
sudo kbd-backlight get          # off | dim | on | auto
sudo kbd-backlight set auto     # set state
sudo kbd-backlight set on
sudo kbd-backlight set dim
sudo kbd-backlight set off
```

---

## Investigation trail

### Step 1 — Kernel sysfs interface

The `ideapad_laptop` kernel module (device `VPC2004`, driver `ideapad_acpi`)
exposes the keyboard backlight via the LED class:

```
/sys/class/leds/platform::kbd_backlight/brightness       # root-owned rw
/sys/class/leds/platform::kbd_backlight/brightness_hw_changed
/sys/class/leds/platform::kbd_backlight/max_brightness   # = 2
```

Polling `brightness` at 100ms while pressing Fn+Space confirmed only 3 values
cycle: `0 → 1 → 2 → 0`. Yet the firmware has 4 states (off / auto / dim / on).

### Step 2 — Auto mode is invisible to sysfs

`brightness` reads `0` in both **off** and **auto** modes. Confirmed by:
- User was in auto mode → `brightness = 0`
- Covering the ambient light sensor (keyboard physically lit in auto mode) →
  `brightness` still `0`, `brightness_hw_changed` still `0`

The kernel driver reads the *configured mode level*, not the physical state.
EC-autonomous brightness changes are invisible to the driver.

### Step 3 — Dead ends explored

**`brightness_hw_changed`** — stays `0` even when EC lights the keyboard in
auto mode. Not useful for detection.

**Ambient light sensor (IIO)**

```
/sys/bus/iio/devices/iio:device1/   name: als
  in_illuminance_raw          → always 0
  in_intensity_both_raw       → always 0
```

Sensor appears to need a hardware trigger/buffer before delivering readings.
Direct sysfs polling does not work.

**EC register access via `ec_sys`** — module loads but creates no path under
`/sys/kernel/debug/ec/` on this 12th-gen Intel platform.

**DSDT raw binary** — not readable without ACPI tools.

### Step 4 — DSDT decompilation with acpica-tools

Installed `acpica-tools` and `acpi-call-dkms`. Decompiled the DSDT:

```bash
sudo acpidump -b -n DSDT -f /tmp/dsdt.dat
iasl -d /tmp/dsdt.dat        # → /tmp/dsdt.dsl
```

Found the `VPC0` device (`_HID VPC2004`) at `\_SB.PC00.LPCB.EC0.VPC0` with
the `KBLC` method for keyboard backlight control.

EC registers (memory-mapped at `0xFE0B0400`, region `ERAX`):

| Register | Offset | Size | Purpose |
|---|---|---|---|
| `KBGS` | `0x26` | 32-bit | keyboard backlight group state (current) |
| `KBSS` | `0x2B` | 32-bit | keyboard backlight set state (command) |
| `KBGC` | `0x45` | 32-bit | keyboard backlight group config |

`KBLC` method logic (from DSDT):
- `KBLC(0x1)` → returns `KBGC | 1` (device type query)
- `KBLC(arg & 0x0F == 0x2)` → returns `KBGS | 1` (get current state)
- `KBLC(arg & 0x0F == 0x3)` → writes arg to `KBSS`, EC updates `KBGS` (set)

Group selector encoding: bits 7:4 of arg must satisfy
`(arg & 0xFFF0) >> 3 == KBGC & ~1`.

### Step 5 — acpi_call verification

```bash
# Query device type
sudo bash -c 'echo "\_SB.PC00.LPCB.EC0.VPC0.KBLC 0x1" > /proc/acpi/call && cat /proc/acpi/call'
# → 0x7  (KBD_BL_TRISTATE_AUTO = full 4-state support confirmed)
# → KBGC = 6  (group selector = 3, since (0x30) >> 3 = 6 = KBGC & ~1)
```

```bash
# Get current state (auto mode active)
sudo bash -c 'echo "\_SB.PC00.LPCB.EC0.VPC0.KBLC 0x32" > /proc/acpi/call && cat /proc/acpi/call'
# → 0x10007  (KBGS = 0x10006, state bits 2:1 = 11 = 3 = auto)
```

State encoding — KBLC GET returns `KBGS | 1`, state = `(return & 0xFFFE) >> 1`:

| State | KBLC GET return | State bits (2:1) |
|---|---|---|
| off  | `0x10001` | 0 |
| dim  | `0x10003` | 1 |
| on   | `0x10005` | 2 |
| auto | `0x10007` | 3 |

The `0x10000` bit is always set in KBGS and is not part of the state encoding.

SET argument structure (confirmed working):

| State | KBLC SET arg | Bits 19:16 | Bits 7:4 | Bits 3:0 |
|---|---|---|---|---|
| off  | `0x00033` | 0 | 3 (group) | 3 (SET) |
| dim  | `0x10033` | 1 | 3 (group) | 3 (SET) |
| on   | `0x20033` | 2 | 3 (group) | 3 (SET) |
| auto | `0x30033` | 3 | 3 (group) | 3 (SET) |

SET on and SET auto confirmed working (backlight changed visibly, GET returned
correct value afterward).

### Step 6 — Why sysfs hides auto mode

The kernel `ideapad_laptop` driver (6.17) maps GET return value 3 (auto) back
to 0 in sysfs via:
```c
if (value == priv->kbd_bl.led.max_brightness + 1)
    return 0;  // auto mapped to off in sysfs
```

An RFC patch "[RFC PATCH 9/9] platform/x86: ideapad-laptop: Fully support auto
kbd backlight" was submitted to LKML in Feb 2026 but was not merged before
Linux 6.17. Until it lands, the KBLC direct call is the only way to set/detect
auto mode.

---

## Installation

### Step 1 — system install (run once, as root)

Install the `acpi_call` kernel module (required at runtime):

| Distro | Command |
|---|---|
| Debian / Ubuntu / Linux Mint | `sudo apt install acpi-call-dkms` |
| Fedora | `sudo dnf install akmod-acpi_call` |
| Arch | `sudo pacman -S acpi_call-dkms` |

Then run the installer:

```bash
sudo ./install.sh [state]     # default startup state: auto
```

Override startup state: `sudo ./install.sh on`

Installs:
- `/usr/local/bin/kbd-backlight` — control script
- `/etc/modules-load.d/acpi_call.conf` — loads `acpi_call` at boot
- `/etc/systemd/system/kbd-backlight.service` — sets backlight state at boot
- `/etc/sudoers.d/kbd-backlight` — passwordless sudo for the script
- `/usr/lib/systemd/system-sleep/kbd-backlight` — saves state before suspend,
  restores it after resume

> All install paths are defined in `config.sh` at the repo root. Edit that
> file to relocate everything before running any install script.

### Step 2 — tray app (optional, run as your normal user)

```bash
cd tray-app && ./install.sh
```

Requires Step 1 first. The script checks prerequisites and tells you what's
missing if Step 1 hasn't been run.

Installs:
- `~/.local/bin/kbd-backlight-tray` — GTK system tray app
- `~/.config/autostart/kbd-backlight-tray.desktop` — autostart at login
- `~/.local/share/applications/kbd-backlight-tray.desktop` — app menu entry
  (search "Keyboard Backlight" to relaunch after accidental close)

Launch immediately after install:

```bash
~/.local/bin/kbd-backlight-tray &
```

#### Tray app features

- **Right-click menu** shows current state and radio items to switch between
  Auto / On / Dim / Off
- **State-based tray icon** — uses `keyboard-brightness-*-symbolic` theme icons
  if the active theme provides them, falls back to `input-keyboard`
- **`--icon NAME_OR_PATH`** — override with a fixed icon at launch
- **Fn+Space detection** — sysfs polled every 1 s (no subprocess, no sudo);
  triggers a full ACPI read only when a change is detected
- **Desktop notifications** on external state changes (Fn+Space, terminal,
  post-resume); debounced 1.5 s so rapid cycling produces one notification
  for the final state only
- **Notifications toggle** in the menu — persisted across restarts
- **Run on startup toggle** in the menu — creates/removes the autostart entry
- **Suspend/resume** — backlight state saved before sleep and restored on wake
  by the systemd sleep hook installed in Step 1

#### Optional tray dependencies

| Package | Purpose | Distro install |
|---|---|---|
| `gir1.2-appindicator3-0.1` | Better Cinnamon tray integration | `sudo apt install gir1.2-appindicator3-0.1` |
| `gir1.2-notify-0.7` | Desktop notifications | `sudo apt install gir1.2-notify-0.7` |

Fedora equivalents: `libappindicator-gtk3`, `libnotify`.
Arch equivalents: `libappindicator-gtk3`, `libnotify`.

The app runs without either — AppIndicator3 falls back to `Gtk.StatusIcon`,
notifications are silently disabled.

### Uninstall everything

```bash
sudo ./uninstall.sh     # removes system install + tray app
```

---

## Dependencies

| Package | Purpose | Required |
|---|---|---|
| `acpi-call-dkms` | Direct ACPI method calls at runtime | Yes |
| `python3-gi` | GTK bindings for tray app | Tray app only |
| `gir1.2-appindicator3-0.1` | Better Cinnamon tray integration | Optional |
| `gir1.2-notify-0.7` | Desktop notifications | Optional |
| `acpica-tools` | DSDT decompilation (research only) | No |
