#!/bin/bash
reset

# Copyright (C) 2017, The Linux Foundation. All rights reserved.
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License version 2 and
# only version 2 as published by the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.

# Breakfast version
bake_version=2.0

# Global delay define
delay()
{
	sleep 0.5
}

# Colors
export txtbld=$(tput bold)
export txtrst=$(tput sgr0)
export red=$(tput setaf 1)
export grn=$(tput setaf 2)
export ylw=$(tput setaf 3)
export blu=$(tput setaf 4)
export mgt=$(tput setaf 5)
export cya=$(tput setaf 6)
export bldred=${txtbld}$(tput setaf 1)
export bldgrn=${txtbld}$(tput setaf 2)
export bldylw=${txtbld}$(tput setaf 3)
export bldblu=${txtbld}$(tput setaf 4)
export bldmgt=${txtbld}$(tput setaf 5)
export bldcya=${txtbld}$(tput setaf 6)

# Root directory define
export ROOTDIR=`readlink -f .`

# Breakfast configuration
export BRKFSTCONFIGS="$ROOTDIR/configs"
export OUTPUT="$ROOTDIR/output"

# Board configuration
export NR_CPUS=`grep 'processor' /proc/cpuinfo | wc -l`
export MAXFREQ=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_max_freq)

# Hardcoded configuration
hardcoded_config() {
	# Device configuration
	export KERNSOURCE="$ROOTDIR/src/kernel/$SOURCE"
	export KERNFLASHABLE="$ROOTDIR/src/flashable/$FLASHABLE"
	export CROSS_COMPILE="$ROOTDIR/toolchain/$TOOLCHAIN/bin/${TOOLCHAIN}-"
	export KERNIMG="$KERNSOURCE/arch/$ARCH/boot/$IMGTYPE"
	if [ -e $KERNSOURCE/arch/$ARCH/configs/$CONFIG ]; then
		export VERSION=$(cat $KERNSOURCE/arch/$ARCH/configs/$CONFIG | grep "CONFIG_LOCALVERSION=" | dd bs=1 skip=22 count=$VCOUNT 2>/dev/null)
	fi
}

# External configuration support
config_picker() {
	# Check the configuration directory
	if [ -e $BRKFSTCONFIGS/default.conf ]; then
		echo "${bldmgt}----- List of available configs: ${txtrst}"; delay

		# Trap into configs directory and print all the configs there
		cd $BRKFSTCONFIGS
		find *.conf

		# Wait until the config will be chosen from userspace
		read -p "${bldmgt}----- Choose the config from the list (without .conf): ${txtrst}" selected_config

		# Check for the selected config
		if [ -e $BRKFSTCONFIGS/${selected_config}.conf ]; then
			# Initialize the config if there is one
			echo "${selected_config}.conf" > $BRKFSTCONFIGS/cur_config

			# Compare configurations' names
			if [ "$(cat $BRKFSTCONFIGS/cur_config)" = "${selected_config}.conf" ]; then
				echo "${bldgrn}----- SUCCESS: ${selected_config}.conf is picked!${txtrst}"; delay
				# Go back to the root directory
				cd $ROOTDIR
			else
				# Stop the process if this gone wrong
				echo "${bldred}----- ERROR: ${selected_config}.conf is not picked!${txtrst}"; delay
			fi
		else
			# Stop the process if there is no such config
			echo "${bldred}----- ERROR: ${selected_config}.conf is not found!${txtrst}"
			echo "${bldred}----- Please, check out its name and try again!${txtrst}"; delay; exit 0
		fi
	else
		# Stop the process if there is no configuration directory
		echo "${bldred}----- ERROR: Configuration directory is not found!${txtrst}"; delay
		echo "${bldred}----- Please, ensure that you have installed Breakfast correctly!${txtrst}"; delay; exit 0
	fi
}

# External configuration loader
config_loader() {
	# Check the config by checking its size
	if [ -s $BRKFSTCONFIGS/cur_config ]; then
		CUR_CONFIG="$(cat $BRKFSTCONFIGS/cur_config)"
		# Load the config if there is one
		source $BRKFSTCONFIGS/$CUR_CONFIG; hardcoded_config
		echo "${bldgrn}----- SUCCESS: $CUR_CONFIG is loaded!${txtrst}"; delay
		# Do not continue if it is default.conf
		if [ "$CUR_CONFIG" = "default.conf" ]; then
			echo "${bldred}----- ERROR: default.conf is not ready for building!${txtrst}"
			echo "${bldred}----- Please, initialize another config!${txtrst}"; delay; exit 0
		fi
	else
		# Create a new config using config_picker()
		echo "${bldylw}----- WARNING: cur_config is empty!${txtrst}"; delay
		echo "${bldylw}----- Starting config_picker...${txtrst}"; delay
		config_picker
		CUR_CONFIG="$(cat $BRKFSTCONFIGS/cur_config)"
		# Load the config if there is one
		source $BRKFSTCONFIGS/$CUR_CONFIG; hardcoded_config
		# Do not continue if it is default.conf
		if [ "$CUR_CONFIG" = "default.conf" ]; then
			echo "${bldred}----- ERROR: default.conf is not ready for building!${txtrst}"
			echo "${bldred}----- Please, initialize another config!${txtrst}"; delay; exit 0
		fi
	fi
}

# Remove all the built stuff
hard_clean()
{
	rm -rf $KERNIMG
	rm -rf $KERNFLASHABLE/core/$IMGTYPE
}

# Simple check for stuff
check()
{
	echo "${bldcya}----- Checking the source...${txtrst}"; delay

	# Check the Breakfast tree presence
	if [ ! -e $BRKFSTCONFIGS ]; then
		echo "${bldred}----- ERROR: No Breakfast configs have been found!${txtrst}"; delay
		echo "${bldred}----- Please, ensure that you have installed breakfast correctly!${txtrst}"; delay; exit 0
	fi

	# Check the Linux tree presence
	if [ ! -e $KERNSOURCE/arch ]; then
		echo "${bldred}----- ERROR: No Linux source has been found!${txtrst}"; delay
		echo "${bldred}----- Please, download the source and try again!${txtrst}"; delay; exit 0
	fi

	# Check the Toolchain presence
	if [ ! -f ${CROSS_COMPILE}gcc ]; then
		echo "${bldred}----- ERROR: Cannot find GCC!${txtrst}"; delay; exit 0
		echo "${bldred}----- Please, download the GCC and try again!${txtrst}"; delay; exit 0
	fi

	# Check the flashable structure presence
	if [ ! -f $KERNFLASHABLE/META-INF/com/google/android/update-binary ]; then
		echo "${bldylw}----- WARNING: No output structure found!${txtrst}"; delay
		echo "${bldred}----- Please, establish the output structure!${txtrst}"; delay
	fi

	echo "${bldgrn}----- SUCCESS: Source was checked!${txtrst}"; delay
}

# Clean leftover junk
clean_junk()
{
	# Find and remove files via parallel
	find . -type f \( -iname \*.rej \
		       -o -iname \*.orig \
		       -o -iname \*.bkp \
		       -o -iname \*.ko \
		       -o -iname \*.c.BACKUP.[0-9]*.c \
		       -o -iname \*.c.BASE.[0-9]*.c \
		       -o -iname \*.c.LOCAL.[0-9]*.c \
		       -o -iname \*.c.REMOTE.[0-9]*.c \
		       -o -iname \*.org \) \
				| parallel rm -fv {}
}

# Main cleaning function
clean()
{
	echo "${bldcya}----- Cleaning up source...${txtrst}"; delay

	# Trap into kernel source
	cd $KERNSOURCE

	# Remove junk files
	clean_junk

	# Clean the tree via base cleaning functions
	make mrproper
	make clean

	# Clean leftover files
	rm -rf $KERNSOURCE/arch/$ARCH/boot/*.dtb
	rm -rf $KERNSOURCE/arch/$ARCH/boot/*.cmd
	# 'mach-msm' directory is present on old ARM kernels
	if [ "$ARCH" = "arm" ]; then
		rm -rf $KERNSOURCE/arch/arm/mach-msm/smd_rpc_sym.c
	fi
	rm -rf $KERNSOURCE/arch/$ARCH/crypto/aesbs-core.S
	rm -rf $KERNSOURCE/include/generated
	rm -rf $KERNSOURCE/arch/*/include/generated
	rm -rf $KERNIMG
	# Remove the built kernel
	rm -rf $KERNFLASHABLE/core/$IMGTYPE

	# Go back to root
	cd $ROOTDIR

	# Check the source after cleaning and print the result
	if [ ! -e $KERNSOURCE/scripts/basic/fixdep ]; then
		echo "${bldgrn}----- SUCCESS: Successfully cleaned!${txtrst}"; delay
	else
		echo "${bldred}----- ERROR: Could not cleanup the tree!${txtrst}"; delay; exit 0
	fi
}

# Complete cleaning of the tree
full_clean()
{
	# Trap into kernel source
	cd $KERNSOURCE

	# Remove junk files
	clean_junk

	# Intelligent cleaning verification requirement
	if [ -e $KERNSOURCE/scripts/basic/fixdep ]; then
		# 'clean' function takes a while, so this check is needed
		clean
	else
		# Go back to root
		cd $ROOTDIR

		echo "${bldgrn}----- SUCCESS: Source is already cleaned!${txtrst}"; delay
	fi
}

# Defconfig creator
crt_config()
{
	echo "${bldcya}----- Checking for defconfig...${txtrst}"; delay

	# Trap into kernel source
	cd $KERNSOURCE

	# Create the config only if there is no one
	if [ ! -f $KERNSOURCE/arch/$ARCH/configs/$CONFIG ]; then
		echo "${bldcya}----- Creating defconfig...${txtrst}"; delay

		# Break up, if there is no original defconfig
		if [ ! -e $KERNSOURCE/arch/$ARCH/configs/$ORIGCONFIG ]; then
			echo "${bldred}----- ERROR: Could not find an original defconfig!${txtrst}"; delay; exit 0
		fi

		# Created defconfig should not replace the original defconfig
		if [ "$CONFIG" = "$ORIGCONFIG" ]; then
			echo "${bldred}----- ERROR: Configs names are the same!${txtrst}"; delay; exit 0
		fi

		# Make an original defconfig and load in to the tree
		make $ORIGCONFIG
		mv .config $KERNSOURCE/arch/$ARCH/configs/$CONFIG

		# Clean the tree after this process
		clean

		# Check the tree and print the result
		if [ -e $KERNSOURCE/arch/$ARCH/configs/$CONFIG ]; then
			echo "${bldgrn}----- SUCCESS: Defconfig was successfully created!${txtrst}"; delay
		else
			echo "${bldred}----- ERROR: Could not create a defconfig!${txtrst}"; delay; exit 0
		fi
	else
		# There is no sense to do this if we already have a defconfig
		echo "${bldgrn}----- SUCCESS: Defconfig was found!${txtrst}"; delay
	fi

	# Go back to root
	cd $ROOTDIR
}

# Flashable archive creator
crt_flashable()
{
	echo "${bldcya}----- Creating flashable archive...${txtrst}"; delay

	# Trap into flashable structure
	cd $KERNFLASHABLE

	# Remove all the prebuilt kernels
	rm -rf *.zip

	# Use VERSION as a name if it is defined
	if [ $VERSION ]; then
		zip -r ${VERSION}-$(date +"%Y%m%d").zip .
	else
		# If no, then simply use KERNNAME with the current date
		zip -r ${KERNNAME}-$(date +"%Y%m%d").zip .
	fi

	# Check the SOURCE dependency in output directory
	if [ ! -e $OUTPUT/$SOURCE/ ]; then
		mkdir -p $OUTPUT/$SOURCE/
	fi
	if [ ! -e $OUTPUT/archived/$SOURCE/ ]; then
		mkdir -p $OUTPUT/archived/$SOURCE/
	fi

	# Check the tree and print the result
	if [ -e $KERNFLASHABLE/${KERNNAME}*.zip ]; then
		if [ -e $OUTPUT/$SOURCE/${KERNNAME}*.zip ]; then
			mv -f $OUTPUT/$SOURCE/${KERNNAME}*.zip $OUTPUT/archived/$SOURCE
		fi
		mv $KERNFLASHABLE/${KERNNAME}*.zip $OUTPUT/$SOURCE/
		echo "${bldgrn}----- SUCCESS: Flashable archive was successfully created!${txtrst}"; delay
	else
		echo "${bldred}----- ERROR: Failed to create an archive!${txtrst}"; delay; exit 0
	fi

	# Go back to the root
	cd $KERNSOURCE
}

# Kernel creator (^_^)
crt_kernel() {
	echo "${bldcya}----- Building -> ${VERSION}${txtrst}"; delay

	# Trap into kernel source
	cd $KERNSOURCE

	# Initialize the config and start the building
	make $CONFIG
	make -j$NR_CPUS $IMGTYPE

	# Check the presence of the compiled kernel image
	if [ -e $KERNIMG ]; then
		# Move image to the flashable structure
		mv $KERNIMG $KERNFLASHABLE/core/

		# Create a flashable archive with the compiled kernel
		crt_flashable
		# Clean the tree after this process
		clean

		# Check the tree and print the result
		if [ -e $OUTPUT/$SOURCE/${KERNNAME}*.zip ]; then
			echo "${bldmgt}----- SUCCESS: Kernel was successfully built!${txtrst}"; delay
		else
			echo "${bldred}----- ERROR: Could not find the kernel!${txtrst}"; delay; exit 0
		fi
	else
		# Print error if there is no image
		echo "${bldred}----- ERROR: Kernel STUCK in build!${txtrst}"; delay; exit 0
	fi
}

# Main initialization function
init() {
	# Prepare for the building
	check
	crt_config

	echo "${bldblu}----- Build starts in 3${txtrst}"; sleep 1
	echo "${bldblu}----- Build starts in 2${txtrst}"; sleep 1
	echo "${bldblu}----- Build starts in 1${txtrst}"; sleep 1

	# Then start it
	crt_kernel
}
