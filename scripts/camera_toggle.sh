#!/bin/bash
# F8 (camera) workaround: this key never generates an ACPI/WMI event
# on this model (confirmed via acpi_listen - see README, "F8 / camera"
# section). Bind this to Meta+F8 in System Settings -> Shortcuts.
#
# Set your own USB path below (lsusb, or check dmesg when the camera
# is plugged in).

USB_DEVICE_PATH="/sys/bus/usb/devices/1-3/authorized"

STATUS=$(cat "$USB_DEVICE_PATH")
if [ "$STATUS" -eq "1" ]; then
    sudo bash -c "echo 0 > $USB_DEVICE_PATH"
    notify-send "Security" "Camera DISABLED" -i camera-disabled
else
    sudo bash -c "echo 1 > $USB_DEVICE_PATH"
    notify-send "Security" "Camera ENABLED" -i camera-web
fi
