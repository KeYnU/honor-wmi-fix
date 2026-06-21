# HONOR MagicBook (BRI-XX) - Fn-row keys fix (F8-F12)

Frees up F10-F12 from their default KDE Plasma actions so they can be
rebound to custom shortcuts, plus a working workaround for F8
(camera), which has no software fix.

## Environment

- CachyOS Linux (Arch-based)
- Kernel `7.0.12-1-cachyos`
- KDE Plasma 6.7.0 (Wayland)
- AMD Ryzen 7 8845HS / Radeon 780M
- Driver: `huawei-wmi-dkms-git` (fork of aymanbagabas/Huawei-WMI), version `3.4`
  - not the in-tree kernel module. This dkms version already handles
  the touchpad toggle correctly out of the box (`0x283`/`0x2a3` ->
  `KEY_TOUCHPAD_ON/OFF`), left untouched.

## Problem

The HONOR keyboard controller wraps F-key presses in proprietary WMI
events (bus `wmi / PNP0C14:00`, device `Huawei WMI hotkeys`). By
default:

| Key | WMI scan code | Driver mapping | KDE system action |
|---|---|---|---|
| F10 | `0x28a` | `KEY_CONTROLPANEL` | - |
| F11 | `0x28b` | `KEY_NOTIFICATION_CENTER` | - |
| F12 | `0x28e` | `KEY_SELECTIVE_SCREENSHOT` | Screenshot (same as `Ctrl+Shift+S`) |

These codes are hardcoded as system actions and can't be rebound
through the normal "record shortcut" dialog in System Settings - it
wouldn't even pick up the keypress.

F8 (camera) didn't generate any event in `evtest` either, on the
in-tree module without dkms. Turned out to be a separate, hardware-
level issue (see the F8 section below).

## Diagnosis - why the first two attempts failed

### Attempt 1 - `KEY_F21/F22/F23`

Remapped `0x28a/0x28b/0x28e` to `KEY_F21/F22/F23`. Looked correct in
`evtest`. But **F22 is hardcoded as `XF86TouchpadOn`** in
`/usr/share/X11/xkb/symbols/inet` - so pressing F11 actually
duplicated the hardware touchpad toggle at the libinput/KWin level,
regardless of the driver. Checked the whole `F13-F24` range: all of
it is taken by XF86 multimedia symbols (Tools, Launch5-9, Search,
Touchpad*, Assistant, etc). Not usable.

### Attempt 2 - `KEY_MACRO1/2/3`

Found a range that looked clean - `KEY_MACRO1/2/3` (656/657/658),
mapped to `XF86Macro1/2/3` in `inet`, with no built-in KWin logic
(unlike Touchpad*). `evtest` and `wev` both confirmed events arrived
with the correct keysym and the touchpad wasn't affected.

But the "record shortcut" dialog in System Settings -> Shortcuts
simply didn't react to these keys - empty field, no matter what.

Full diagnosis chain (`evdev -> libinput -> xkb -> Wayland client ->
KWin -> KGlobalAccel -> Qt`):

1. `wev` confirmed the Wayland client receives `XF86Macro1/2/3` with
   the correct keysym - the xkb/Wayland layer works fine.
2. `qdbus .../shortcutNames` showed nothing registered for the Macro
   range on the first check.
3. Checked Qt's key enum via PyQt6: no `XF86Macro*`, but also no
   `XF86*` entries at all - turned out to be the wrong check, since
   `registerShortcut()` in KWin Scripts works with strings, not the
   `Qt::Key` enum directly.
4. Wrote a test KWin Script using `registerShortcut()` with
   `XF86Macro1/2/3` and, separately, with standard codes
   (`XF86Find`, `XF86Tools`, `XF86Launch5`). All six got registered
   in KGlobalAccel (visible via `allShortcutInfos`), but every single
   one showed the same key value: `33554431` (`0x1FFFFFF`) - an
   "unassigned" placeholder, not a real keysym.
5. Found a known quirk: in current KWin Scripting API versions, the
   `keySequence` argument of `registerShortcut()` is ignored as a
   default binding, no matter what string is passed. That's why all
   six tests failed for the same reason - not because of the specific
   key codes.
6. The deciding check: the physical F7 key (`KEY_MICMUTE`, `0x287`)
   *did* get picked up by the "record shortcut" dialog, while
   Macro1-3 didn't. So it wasn't a Wayland-session-wide issue -
   specifically, Qt has no valid `Qt::Key` for `XF86Macro*`, unlike
   long-standing standard multimedia codes like MicMute.

### Fix - standard multimedia codes

Switched to codes from the long-stable, properly Qt-supported list:

| Key | WMI scan code | Linux keycode | evdev code |
|---|---|---|---|
| F10 | `0x28a` | `KEY_MAIL` | 155 |
| F11 | `0x28b` | `KEY_CALC` | 140 |
| F12 | `0x28e` | `KEY_DOCUMENTS` | 235 |

Confirmed: `KEY_CALC` opened the system calculator on first test
(Plasma intercepts it as a built-in action - easy to override with a
custom shortcut, same as F10/F12). F10 and F12 aren't intercepted by
anything and are immediately visible/assignable in System Settings ->
Shortcuts -> Custom Shortcuts.

## The patch

See [`patches/huawei-wmi-fn-keys.patch`](patches/huawei-wmi-fn-keys.patch).

```diff
- { KE_KEY,     0x28a,              { KEY_CONTROLPANEL } },
+ { KE_KEY,     0x28a,              { KEY_MAIL } },

- { KE_KEY,     0x28b,              { KEY_NOTIFICATION_CENTER } },
+ { KE_KEY,     0x28b,              { KEY_CALC } },

- { KE_KEY,     0x28e,              { KEY_SELECTIVE_SCREENSHOT } },
+ { KE_KEY,     0x28e,              { KEY_DOCUMENTS } },
```

(`0x283`/`0x2a3` -> `KEY_TOUCHPAD_ON/OFF` left untouched - already
worked correctly out of the box on dkms 3.4.)

## Usage

```bash
git clone https://github.com/KeYnU/honor-wmi-fix.git
cd honor-wmi-fix
chmod +x scripts/install.sh
./scripts/install.sh
```

The script backs up the original `huawei-wmi.c`, applies the `sed`
replacement, prints the result for review, and asks for confirmation
before rebuilding the dkms module.

To revert - `./scripts/restore.sh` (uses the most recent backup).

### Verifying

```bash
sudo evtest /dev/input/eventX   # find "Huawei WMI hotkeys" in the device list
```

Expected output on F10/F11/F12:

```
F10 -> MSC_SCAN 28a -> KEY_MAIL (155)
F11 -> MSC_SCAN 28b -> KEY_CALC (140)
F12 -> MSC_SCAN 28e -> KEY_DOCUMENTS (235)
```

## Setting up shortcuts in KDE

System Settings -> Shortcuts -> Custom Shortcuts -> New -> Global
Shortcut -> Command/URL. When recording the key combo, press the
F-key - it should now show up as `Mail`, `Calculator`, or
`Documents`.

Mine current setup:

| Key | Action |
|---|---|
| F10 | V2rayN |
| F11 | KDE Connect |
| F12 | Spectacle (screenshot) - overrides the old default `KEY_SELECTIVE_SCREENSHOT`/`Print` binding |

## F8 (camera) - no software fix exists

Unlike F10-F12, F8 isn't a driver/mapping problem. Checked with
`acpi_listen`:

```bash
sudo acpi_listen
# pressing F8 - no new/distinct event,
# only background noise (battery, periodic wmi heartbeat)
```

Pressing F8 generates **no ACPI/WMI event at all** - the key is
handled entirely by the Embedded Controller at the firmware level and
never reaches Linux through standard ACPI channels. There's nothing
for `huawei-wmi.c` to intercept - the event simply doesn't exist at
the OS level.

**Workaround:** instead of catching the key, trigger the desired
action directly (toggling the USB camera's `authorized` flag) on a
different key combo.

See [`scripts/camera_toggle.sh`](scripts/camera_toggle.sh) - bound to
`Meta+F8` in System Settings -> Shortcuts. Update `USB_DEVICE_PATH`
to match your camera (`lsusb`, or check `dmesg` when plugging it in).

## Repo structure

```
.
├── README.md
├── patches/
│   └── huawei-wmi-fn-keys.patch   # unified diff for huawei-wmi.c
└── scripts/
    ├── install.sh                 # applies the patch + rebuilds dkms
    ├── restore.sh                 # reverts to the original from backup
    └── camera_toggle.sh           # F8 workaround (Meta+F8)
```

## Notes for later

- After a kernel update dkms should rebuild automatically, but if an
  AUR package update overwrites the changes inside `huawei-wmi.c`,
  just re-run `./scripts/install.sh`.
- If you ever want to free F11 from the system calculator and rebind
  it too, that's just a new custom shortcut in System Settings - no
  need to touch the kernel side again.
