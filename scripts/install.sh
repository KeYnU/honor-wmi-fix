#!/bin/bash
set -e

DKMS_SRC="/usr/src/huawei-wmi-3.4/huawei-wmi.c"
DKMS_VER="3.4"

if [ ! -f "$DKMS_SRC" ]; then
    echo "Source file not found: $DKMS_SRC - check your huawei-wmi-dkms-git version (dkms status)"
    exit 1
fi

echo "Backing up original file"
sudo cp "$DKMS_SRC" "${DKMS_SRC}.bak.$(date +%s)"

echo "Applying F10/F11/F12 mapping"
sudo sed -i \
  -e 's/{ KE_KEY,     0x28a,              { KEY_CONTROLPANEL } }/{ KE_KEY,     0x28a,              { KEY_MAIL } }/' \
  -e 's/{ KE_KEY,     0x28b,              { KEY_NOTIFICATION_CENTER } }/{ KE_KEY,     0x28b,              { KEY_CALC } }/' \
  -e 's/{ KE_KEY,     0x28e,              { KEY_SELECTIVE_SCREENSHOT } }/{ KE_KEY,     0x28e,              { KEY_DOCUMENTS } }/' \
  "$DKMS_SRC"

echo "Result (lines 134-152):"
sed -n '134,152p' "$DKMS_SRC"

echo ""
echo "If you see KEY_MAIL / KEY_CALC / KEY_DOCUMENTS above, you're good to continue."
read -p "Rebuild the dkms module and reload the driver now? [y/N] " confirm
if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
    echo "Stopped. File was modified but the module was not rebuilt."
    exit 0
fi

echo "Rebuilding dkms module"
sudo dkms remove huawei-wmi/$DKMS_VER --all
sudo dkms install huawei-wmi/$DKMS_VER

echo "Reloading kernel module"
sudo modprobe -r huawei_wmi
sudo modprobe huawei_wmi

echo ""
echo "Done. Verify with: sudo evtest /dev/input/eventX (find 'Huawei WMI hotkeys')"
echo "Expected: F10 -> KEY_MAIL (155), F11 -> KEY_CALC (140), F12 -> KEY_DOCUMENTS (235)"
