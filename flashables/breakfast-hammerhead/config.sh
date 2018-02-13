#!/sbin/sh

TARGET="hammerhead"
KERNEL_IMAGE="zImage-dtb"

API_LOWER="23"
API_UPPER="25"

MPDECISION="/system/bin/mpdecision"
THERMAL_ENGINE="/system/bin/thermal-engine-hh"
THERMAL_CONFIG="/system/etc/thermal-engine-8974.conf"
POWER_HAL="/system/lib/hw/power.$TARGET.so"
