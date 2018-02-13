#!/sbin/sh

TARGET="flo"
KERNEL_IMAGE="zImage"

API_LOWER="23"
API_UPPER="25"

MPDECISION="/system/bin/mpdecision"
THERMAL_ENGINE="/system/bin/thermald"
THERMAL_CONFIG="/system/etc/thermald.conf"
POWER_HAL="/system/lib/hw/power.$TARGET.so"
