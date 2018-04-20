#!/sbin/sh

# Device name the kernel was built for.
TARGET="flo"

# Kernel image type. This one must be placed in package.
KERNEL_IMAGE="zImage"

# Android API table:
# 19 --> Android 4.4.x KitKat.
# 20 --> Android 4.4W KitKat.
# 21 --> Android 5.0.x Lollipop.
# 22 --> Android 5.1.x Lollipop.
# 23 --> Android 6.0.x Marshmallow.
# 24 --> Android 7.0.0 Nougat.
# 25 --> Android 7.1.x Nougat.
# 26 --> Android 8.0.0 Oreo.
# 27 --> Android 8.1.0 Oreo.

# Lowest supported Android API level.
API_LOWER="23"

# Highest supported Android API level.
API_UPPER="25"

# Path to proprietary mpdecision binary.
MPDECISION="/system/bin/mpdecision"

# Path to proprietary thermal engine binary.
THERMAL_ENGINE="/system/bin/thermald"

# Path to thermal engine configuration file. Can be replaced by one in package.
THERMAL_CONFIG="/system/etc/thermald.conf"

# Path to PowerHAL shared library. Required for mpdecision-compatible builds.
POWER_HAL="/system/lib/hw/power.$TARGET.so"
