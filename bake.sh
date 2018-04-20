#!/bin/bash
clear

# Copyright (C) 2017-2018, Alex Saiko <solcmdr@gmail.com>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License version 2 and
# only version 2 as published by the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.

# Version number of this script.
BREAKFAST_VERSION="3.3"

# Flag to reset all applied colors.
COLOR_RESET=$(tput sgr0)
# Initial terminal color plan.
COLOR_BOLD=$(tput bold)
COLOR_GREY=${COLOR_BOLD}$(tput setaf 0)
COLOR_RED=${COLOR_BOLD}$(tput setaf 1)
COLOR_GREEN=${COLOR_BOLD}$(tput setaf 2)
COLOR_YELLOW=${COLOR_BOLD}$(tput setaf 3)
COLOR_BLUE=${COLOR_BOLD}$(tput setaf 4)
COLOR_MAGENTA=${COLOR_BOLD}$(tput setaf 5)
COLOR_CYAN=${COLOR_BOLD}$(tput setaf 6)

# Source directory represents the directory where this script has been sourced.
# Root directory represents the directory where this script is located.
DIR_SOURCE=$(pwd)
DIR_ROOT=$(cd $(dirname ${BASH_SOURCE[0]}) && pwd)
DIR_CONFIGS="$DIR_ROOT/configs"
DIR_KERNELS="$DIR_ROOT/kernels"
DIR_SIGNAPK="$DIR_ROOT/signapk"
DIR_FLASHABLES="$DIR_ROOT/flashables"
DIR_INSTALLER="$DIR_FLASHABLES/breakfast-installer"
DIR_TOOLCHAINS="$DIR_ROOT/toolchains"
DIR_OUTPUTS="$DIR_ROOT/outputs"

# A special directory where a ready installer archive is made up.
TMP_FLASHABLES="$DIR_FLASHABLES/.tmp"

# Bake uses the number of threads which is equal to the doubled number of all
# logical processors to boost the compilation.
NUM_THREADS=$[ $(grep "processor" /proc/cpuinfo | wc -l) * 2 ]

# Automatical Git tagging support.
AUTOTAGGING="true"
NAMETAG="breakfast"

# A simple color-expecting print function with a 0.125 delay for smooth output
# of concurrent prints.
print() { printf "${1}${COLOR_RESET}\n"; sleep 0.125; }

terminate()
{
	case "$1" in
	EISDMG)
		msg="Bake script is damaged!\n! Broken part --> $2";;
	EINVAL)
		msg="No argument passed.";;
	ENOENT)
		msg="$2 was not found.";;
	ENLOAD)
		msg="$2 was not loaded.";;
	EFAULT)
		msg="Kernel stuck in build.";;
	ENFLSH)
		msg="Unable to create flashable archive.";;
	EIO)
		msg="I/O failure.";;
	*)
		msg="Unknown error.";;
	esac

	# Remove temporary flashable directory as it will be overwritten anyway.
	rm -rf $TMP_FLASHABLES

	print "${COLOR_RED}! $msg\n\nScript terminated with errno $1" &&
	# Print uses a 0.125 seconds delay, hence 2.875 should be used here to
	# provide overall 3 seconds delay before the exit.
	sleep 2.875 && exit 1
}

config_loaded()
{
	# Check whether all the required variables are actually set.
	[ ! -z ${ARCH+x} ] && [ ! -z ${SUBARCH+x} ] &&
	[ ! -z ${KERNEL_SOURCE+x} ] && [ ! -z ${DEFAULT_CONFIGURATION+x} ] &&
	[ ! -z ${TARGET_TOOLCHAIN+x} ] && [ ! -z ${KERNEL_TYPE+x} ] &&
	[ ! -z ${CCACHE_USED+x} ] && [ ! -z ${CROSS_COMPILE+x} ] &&
	return 0 || return 1
}

prepare_environment()
{
	print "${COLOR_CYAN}- Preparing working environment..."

	# Unset all the required variables to avoid the theoretical conflicts.
	for var in ARCH SUBARCH \
		   KERNEL_SOURCE \
		   DEFAULT_CONFIGURATION \
		   TARGET_TOOLCHAIN \
		   KERNEL_TYPE \
		   CCACHE_USED \
		   CROSS_COMPILE; do
		unset $var;
	done
}

load_config()
{
	# This function expects an argument to be passed.
	[ ! -z ${1+x} ] || terminate EINVAL

	# Try to find a requested configuration in an appropriate directory.
	TARGET_CONFIG=$(find $DIR_CONFIGS/$1* -printf "%f\n" -quit 2>/dev/null)
	[ ! -z ${TARGET_CONFIG+x} ] || terminate ENOENT "$1"

	print "${COLOR_MAGENTA}- Loading Bake configuration --> $TARGET_CONFIG"
	# Prepare Bash environment before sourcing the new configuration file.
	prepare_environment

	# Load information from configuration file to Bash environment and
	# setup cross compiler path.
	source $DIR_CONFIGS/$TARGET_CONFIG &&
	export CROSS_COMPILE="$DIR_TOOLCHAINS/$TARGET_TOOLCHAIN/bin/${TARGET_TOOLCHAIN}-"

	# Ensure all the things have been made properly.
	print "${COLOR_MAGENTA}- Validating Bake configuration..."
	(config_loaded) || terminate ENLOAD "$TARGET_CONFIG"

	print "${COLOR_GREEN}- $TARGET_CONFIG was successfully loaded!"
}

prepare_kernel_tree()
{
	# This function cannot work without a configuration loaded.
	(config_loaded) || terminate ENLOAD "Bake configuration"

	# Ensure there is a work-ready kernel tree.
	[ -f "$DIR_KERNELS/$KERNEL_SOURCE/Makefile" ] ||
	terminate ENOENT "$DIR_KERNELS/$KERNEL_SOURCE/Makefile"

	print "${COLOR_CYAN}- Preparing ${KERNEL_SOURCE} tree..."

	# Trap into kernel source tree.
	cd $DIR_KERNELS/$KERNEL_SOURCE

	# Do basic clean-up of the tree via Makefile-provided methods.
	[ -e "scripts/basic/fixdep" ] && (make clean mrproper)

	# Remove leftovers of the compilation.
	rm -rf arch/$ARCH/boot/*.dtb		\
	       arch/$ARCH/boot/*.cmd		\
	       arch/$ARCH/crypto/aesbs-core.S	\
	       arch/*/include/generated		\
	       include/generated

	# Try to remove *unneeded* files via parallel if supported.
	[ $(which parallel) ] &&
	find . -type f \( -iname \*.rej			\
		       -o -iname \*.orig		\
		       -o -iname \*.bkp			\
		       -o -iname \*.ko			\
		       -o -iname \*.c.BACKUP.[0-9]*.c	\
		       -o -iname \*.c.BASE.[0-9]*.c	\
		       -o -iname \*.c.LOCAL.[0-9]*.c	\
		       -o -iname \*.c.REMOTE.[0-9]*.c	\
		       -o -iname \*.org \)		\
				| parallel rm -fv { }

	# Tree-specific clean-ups.
	case $TARGET_CONFIG in
	"hammerhead.conf") rm -f arch/$ARCH/mach-msm/smd_rpc_sym.c;;
	esac

	cd $DIR_SOURCE
}

sign_package()
{
	# This function expects an argument to be passed.
	[ ! -z ${1+x} ] || terminate EINVAL

	# Check the presence of the required files.
	[ -f $DIR_SIGNAPK/signapk.jar ] && [ -f $DIR_SIGNAPK/keys/*.pk8 ] &&
	[ -f $DIR_SIGNAPK/keys/*.pem ] && [ -f "$1" ] || return 1

	local NAME=$(basename "$1")
	print "${COLOR_CYAN}- Signing $NAME package..."

	# Setup private and public keys.
	PVKEY=$(find $DIR_SIGNAPK/keys/*.pk8 | head -1)
	PBKEY=$(find $DIR_SIGNAPK/keys/*.pem | head -1)

	# Sign a target package with the previously set keys.
	java -jar $DIR_SIGNAPK/signapk.jar $PBKEY $PVKEY $1 $DIR_SIGNAPK/$NAME

	# Move a signed archive back to the source.
	mv -f $DIR_SIGNAPK/$NAME $1

	print "${COLOR_GREEN}- $NAME was successfully signed!"
}

__make_kernel()
{
	# This function expects configuration to be loaded.
	(config_loaded) || terminate ENLOAD "Bake configuration"

	# Clean-up the working tree and ensure there is one.
	prepare_kernel_tree

	# Trap into kernel tree as it is guaranteed to exist because of the
	# previous call.
	cd $DIR_KERNELS/$KERNEL_SOURCE

	# Try to grab Git branch.
	[ -e "$DIR_KERNELS/$KERNEL_SOURCE/.git" ] &&
	BRANCH=$(git rev-parse --abbrev-ref HEAD) || BRANCH="unknown"

	print "${COLOR_CYAN}- Building $KERNEL_SOURCE (\"$BRANCH\" branch)..."
	# Use 3 seconds delay before the build to start.
	for ((i = 3; i > 0; i--)); do
		print "${COLOR_BLUE}- Build starts in $i..."; sleep 0.875
	done

	# Forcefully tag Git repository if specified.
	[ $AUTOTAGGING == "true" ] &&
	git tag -afm "$NAMETAG" "$NAMETAG" &>/dev/null

	# Start the compilation with NUM_THREADS number of threads using a
	# set-by-config cross compiler. ccache usage should be declared in
	# device-configuration file.
	make $DEFAULT_CONFIGURATION &&
	make -j$NUM_THREADS $KERNEL_TYPE \
	     REAL_CC="$CCACHE_USED ${CROSS_COMPILE}gcc"

	# Ensure the kernel has been compiled succssfully.
	[ -f "$DIR_KERNELS/$KERNEL_SOURCE/arch/$ARCH/boot/$KERNEL_TYPE" ] ||
	terminate EFAULT

	print "${COLOR_GREEN}- $KERNEL_SOURCE was successfully built!"
	cd $DIR_SOURCE
}

__make_flashable()
{
	# This function expects configuration to be loaded.
	(config_loaded) || terminate ENLOAD "Bake configuration"

	print "${COLOR_CYAN}- Creating flashable kernel..."

	# Ensure all the required directories and files are actually set up.
	[ -s "$DIR_INSTALLER" ] ||
	terminate ENOENT "$DIR_INSTALLER"

	[ -s "$DIR_FLASHABLES/$KERNEL_SOURCE" ] ||
	terminate ENOENT "$DIR_FLASHABLES/$KERNEL_SOURCE"

	[ -s "$DIR_KERNELS/$KERNEL_SOURCE/arch/$ARCH/boot/$KERNEL_TYPE" ] ||
	terminate ENOENT \
		 "$DIR_KERNELS/$KERNEL_SOURCE/arch/$ARCH/boot/$KERNEL_TYPE"

	# Regenerate temporary directory for flashable structure.
	rm -rf $TMP_FLASHABLES && mkdir $TMP_FLASHABLES

	# Extract both Breakfast installer and device-specific data to the
	# temporary directory and check whether it all had been made correctly.
	cp -ax $DIR_INSTALLER/* $TMP_FLASHABLES &&
	cp -ax $DIR_FLASHABLES/$KERNEL_SOURCE/* $TMP_FLASHABLES/kernel/

	[ -f "$TMP_FLASHABLES/kernel/config.sh" ] ||
	terminate ENOENT "$TMP_FLASHABLES/kernel"

	# Move freshly generated kernel image to the temporary directory.
	mv -f $DIR_KERNELS/$KERNEL_SOURCE/arch/$ARCH/boot/$KERNEL_TYPE \
	      $TMP_FLASHABLES/kernel/$KERNEL_TYPE

	# Acquire the current date in Year-Month-Day format.
	DATE=$(date +"%Y%m%d")

	# Try to create a zipped archive with all the data collected in
	# temporary directory. Terminate early in case of a failure.
	cd $TMP_FLASHABLES && zip -r ${KERNEL_SOURCE}-$DATE.zip .
	[ "$?" -eq "0" ] && cd $DIR_SOURCE || terminate EIO

	# Try to sign the newly created flashable archive with the keys created
	# by OpenSSL software. If the keys are absent, nothing will really
	# happen, hence this call is safe from all sides.
	sign_package "$TMP_FLASHABLES/${KERNEL_SOURCE}-$DATE.zip"

	# Ensure "archived" subdirectory actually exists.
	[ -d "$DIR_OUTPUTS/$KERNEL_SOURCE/archived" ] ||
	mkdir -p $DIR_OUTPUTS/$KERNEL_SOURCE/archived

	# Clean-up the kernel-ready directory first. Move all the archives
	# placed within it into a "archived" subdirectory mentioned above.
	mv -f $DIR_OUTPUTS/$KERNEL_SOURCE/$KERNEL_SOURCE*.zip \
	      $DIR_OUTPUTS/$KERNEL_SOURCE/archived/ &>/dev/null

	# Move the recently created flashable kernel into output subdirectory.
	mv $TMP_FLASHABLES/${KERNEL_SOURCE}-$DATE.zip \
	   $DIR_OUTPUTS/$KERNEL_SOURCE/

	# Remove temporary flashable directory as the work is done.
	rm -rf $TMP_FLASHABLES

	# Ensure all the above has been made successfully.
	[ -s "$DIR_OUTPUTS/$KERNEL_SOURCE/${KERNEL_SOURCE}-$DATE.zip" ] ||
	terminate ENFLSH

	print "${COLOR_GREEN}- ${KERNEL_SOURCE}-$DATE.zip was successfully created!"
}

make_kernel()
{
	# This function expects configuration to be loaded.
	(config_loaded) || terminate ENLOAD "Bake configuration"

	# Get current time in Seconds-Nanoseconds format.
	STIME=$(date +"%s.%N")

	# Compile the kernel and turn it into a flashable archive.
	__make_kernel
	__make_flashable

	# Clean-up the tree after the process.
	prepare_kernel_tree

	# Get current time in Seconds-Nanosecods format again.
	ETIME=$(date +"%s.%N")
	# Now the difference between two times actually represents the elapsed
	# time for compilation, creating of a flashable and the clean-up.  We
	# can use bc to calculate the elapsed time properly.
	RTIME=$(echo "scale=1; ($ETIME - $STIME) / 1" | bc)

	print "${COLOR_MAGENTA}- Kernel was successfully built!"
	print "${COLOR_CYAN}- Elapsed time: $RTIME seconds"
}

print "${COLOR_CYAN}- Starting Bake v$BREAKFAST_VERSION..."

# Ensure all the critical directories are created and non-empty.
for DIR in $DIR_CONFIGS \
	   $DIR_KERNELS \
	   $DIR_FLASHABLES \
	   $DIR_TOOLCHAINS \
	   $DIR_OUTPUTS; do
	[ -s "$DIR" ] || terminate EISDMG "$DIR"
done

# Initialize the script immediately if it was not called in a Bash context.
if [ ! "$0" == "bash" ]; then
	[ ! -z ${1+x} ] || terminate EINVAL

	load_config $1
	make_kernel
fi
