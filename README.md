# Lenovo Yoga 9i Gen 7 — Keyboard Backlight Research Notes

Investigation into programmatically reading and setting keyboard backlight
state on Lenovo Yoga 9i Gen 7 (14IAP7) running Linux Mint.

---

## What we found

### The kernel interface

The `ideapad_laptop` kernel module (device `VPC2004`, driver `ideapad_acpi`)
exposes the keyboard backlight via the LED class:

```
/sys/class/leds/platform::kbd_backlight/brightness       # read/write (root)
/sys/class/leds/platform::kbd_backlight/brightness_hw_changed
/sys/class/leds/platform::kbd_backlight/max_brightness   # = 2
```

Reading `brightness` returns 0, 1, or 2. Writing sets the backlight level.
The file is root-owned (`rw-r--r--`).

**The Fn+Space key cycles through 4 firmware states:** off → auto → dim → on

**The kernel only exposes 3 values:**

| `brightness` | State |
|---|---|
| 0 | off |
| 1 | dim |
| 2 | on |

Confirmed by monitoring the file while pressing Fn+Space repeatedly
(`inotify`-style polling at 100ms). The cycle observed was `0 → 1 → 2 → 0`.

### The auto-mode problem

The firmware's "auto" state (EC dims/lights keyboard based on ambient light
sensor) **cannot be detected via sysfs**:

- When entering auto mode via Fn+Space, `brightness` reads `0` — same as off.
- Covering the light sensor while in auto mode turns the keyboard on
  physically, but both `brightness` and `brightness_hw_changed` remain `0`.
- The kernel reports the configured mode level, not the actual hardware state.
  The EC's autonomous brightness changes are invisible to the driver.

### Things tried to detect auto mode

**`brightness_hw_changed`** — updated when hardware changes brightness
independently of software. Stays `0` even when EC lights the keyboard in
auto mode. Not useful.

**Ambient light sensor (IIO)**

```
/sys/bus/iio/devices/iio:device1/   name: als
  in_illuminance_raw
  in_intensity_both_raw
```

Both channels return `0` regardless of actual lighting conditions (sensor
covered or not). The device likely requires a hardware trigger and buffer
enabled before readings are valid — direct sysfs polling does not work.

**EC register access via `ec_sys`**

```bash
sudo modprobe ec_sys
```

Module loads but creates no path under `/sys/kernel/debug/ec/`. The EC on
this 12th-gen Intel platform does not expose debug registers via `ec_sys`.

**DSDT / ACPI tables**

`/sys/firmware/acpi/tables/DSDT` requires root. Tried `strings` and `xxd`
on the raw binary to find VPC2004 backlight method names — no results
(table is not readable as plain text without decompilation).

`acpica-tools` (for `iasl` decompiler) and `acpi-call-dkms` (for direct
ACPI method calls) are available in apt and would be the next step to expose
all 4 firmware states. Not installed.

### systemd-backlight persistence

`systemd-backlight@leds:platform::kbd_backlight.service` already runs at
boot and saves/restores the `brightness` value:

```
/var/lib/systemd/backlight/pci-0000:00:1f.0-platform-VPC2004:00:leds:platform::kbd_backlight
```

So the 3 kernel-accessible states (off/dim/on) persist across reboots
automatically. "auto" mode is lost on reboot.

---

## Practical solution (3 states)

A udev rule makes the brightness file writable by the `input` group so
root is not required. A wrapper script provides human-readable get/set.

See: `kbd-backlight`, `90-kbd-backlight.rules`, `install.sh`

To set on login, add to `~/.profile`:
```bash
kbd-backlight set on
```

---

## Next steps (if auto mode is needed)

Install `acpica-tools` + `acpi-call-dkms`, decompile the DSDT, find the
ACPI method for the keyboard backlight mode register, then call it directly
to read and write all 4 states including "auto".
