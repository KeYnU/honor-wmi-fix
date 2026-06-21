#!/bin/bash
set -e

DKMS_SRC="/usr/src/huawei-wmi-3.4/huawei-wmi.c"
DKMS_VER="3.4"

BACKUP=$(ls -t "${DKMS_SRC}".bak.* 2>/dev/null | head -1)

if [ -z "$BACKUP" ]; then
    echo "No backup found (looked for ${DKMS_SRC}.bak.*)"
    exit 1
fi

echo "Restoring from: $BACKUP"
sudo cp "$BACKUP" "$DKMS_SRC"

sudo dkms remove huawei-wmi/$DKMS_VER --all
sudo dkms install huawei-wmi/$DKMS_VER
sudo modprobe -r huawei_wmi
sudo modprobe huawei_wmi

echo "Original restored."
