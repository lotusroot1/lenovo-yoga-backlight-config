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

```bash
sudo ./install.sh [state]
```

Default startup state is `auto`. Override with: `sudo ./install.sh on`

This installs:
- `/usr/local/bin/kbd-backlight` — control script
- `/etc/modules-load.d/acpi_call.conf` — loads `acpi_call` at boot
- `/etc/systemd/system/kbd-backlight.service` — sets state at boot
- `/etc/sudoers.d/kbd-backlight` — passwordless sudo for the script

---

## Dependencies

- `acpi-call-dkms` — kernel module for direct ACPI method calls
- `acpica-tools` — used during research to decompile DSDT (not needed at runtime)

```bash
sudo apt install acpi-call-dkms
```
