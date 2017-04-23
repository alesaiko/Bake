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

# BF version
bf_ver=2.2.1

# Define a global delay
delay()
{
	sleep 0.5
}

# Export the colors
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

# Define the root directory
export ROOTDIR=`readlink -f .`

# BF structure defines
export BFCONFIGS="$ROOTDIR/configs"
export OUTPUT="$ROOTDIR/output"

# Define NR_CPUS value based on cpus count
export NR_CPUS=`grep 'processor' /proc/cpuinfo | wc -l`

# Load defines from the BF config
load_defines() {
	export KERNSOURCE="$ROOTDIR/src/kernel/$SOURCE"
	export KERNFLASHABLE="$ROOTDIR/src/flashable/$FLASHABLE"
	export CROSS_COMPILE="$ROOTDIR/toolchain/$TOOLCHAIN/bin/${TOOLCHAIN}-"
	export KERNIMG="$KERNSOURCE/arch/$ARCH/boot/$IMGTYPE"
	export VERSION="$SOURCE"
}

# Pick the BF config
config_picker() {
	if [ -e $BFCONFIGS/default.conf ]; then
		echo "${bldmgt}----- Available BF configs: ${txtrst}"; delay

		# Display all the available BF configs
		cd $BFCONFIGS
		find *.conf
		cd $ROOTDIR

		# Display the current BF config
		echo "${bldmgt}----- Current BF config: ${txtrst}"; delay
		if [ -e $BFCONFIGS/.cur_config ]; then
			if [ "$(cat $BFCONFIGS/.cur_config 2>/dev/null)" ]; then
				cat $BFCONFIGS/.cur_config
			else
				echo "${bldylw}----- There is no BF config selected!${txtrst}"; delay
			fi
		else
			echo "${bldylw}----- There is no BF config loaded!${txtrst}"; delay
		fi

		# Read the selected config from terminal
		read -p "${bldmgt}----- Select the BF config: ${txtrst}" selected_config
		if [ ! $selected_config ]; then
			echo "${bldylw}----- No config has been selected!${txtrst}"; delay; exit 0
		elif [ "$selected_config" = "$(cat $BFCONFIGS/.cur_config 2>/dev/null)" ] ||
		     [ "${selected_config}.conf" = "$(cat $BFCONFIGS/.cur_config 2>/dev/null)" ]; then
			echo "${bldylw}----- No changes in cur_config. Continuing...${txtrst}"; delay
		fi

		# Pick the selected BF config
		if [ -e $BFCONFIGS/$selected_config ] ||
		   [ -e $BFCONFIGS/${selected_config}.conf ]; then
			# Load the BF config
			if [ -e $BFCONFIGS/$selected_config ]; then
				export config_name="$selected_config"
				echo "$selected_config" > $BFCONFIGS/.cur_config; delay
			else
				export config_name="${selected_config}.conf"
				echo "${selected_config}.conf" > $BFCONFIGS/.cur_config
			fi

			if [ "$(cat $BFCONFIGS/.cur_config)" = "$config_name" ]; then
				echo "${bldgrn}----- SUCCESS: $config_name was picked!${txtrst}"; delay
			else
				echo "${bldred}----- ERROR: $config_name was not picked!${txtrst}"; delay
			fi
		else
			export config_name="$selected_config"

			echo "${bldred}----- ERROR: $config_name was not found!${txtrst}"; delay
			echo "${bldred}----- Please, check out its name and try again!${txtrst}"; delay; exit 0
		fi
	else
		echo "${bldred}----- ERROR: Configuration directory was not found!${txtrst}"; delay
		echo "${bldred}----- Please, ensure that you have installed Breakfast correctly!${txtrst}"; delay; exit 0
	fi
}

# Load the BF config
config_loader() {
	# Pick config if there is no one
	if [ ! "$(cat $BFCONFIGS/.cur_config 2>/dev/null)" ]; then
		echo "${bldylw}----- WARNING: cur_config is empty!${txtrst}"; delay
		echo "${bldylw}----- Starting config_picker...${txtrst}"; delay

		# Pick the BF config
		config_picker
	fi

	# Initialize BF config
	CUR_CONFIG="$(cat $BFCONFIGS/.cur_config)"
	source $BFCONFIGS/$CUR_CONFIG; load_defines

	if [ $SOURCE ] && [ $ARCH ] && [ $SUBARCH ] && [ $ORIGCONFIG ] &&
	   [ $CONFIG ] && [ $TOOLCHAIN ] && [ $IMGTYPE ] && [ $FLASHABLE ]; then
		echo "${bldgrn}----- SUCCESS: $CUR_CONFIG was loaded!${txtrst}"; delay
	else
		echo "${bldred}----- ERROR: $CUR_CONFIG was not loaded!${txtrst}"; delay; exit 0
	fi
}

# Remove all the built stuff
hard_clean()
{
	rm -rf $KERNIMG
	rm -rf $KERNFLASHABLE/kernel/$IMGTYPE
}

# Check for the stuff
check()
{
	echo "${bldcya}----- Checking BF...${txtrst}"; delay

	if [ ! -e $BFCONFIGS ]; then
		echo "${bldred}----- ERROR: Breakfast configs were not found!${txtrst}"; delay
		echo "${bldred}----- Please, ensure that you have installed Breakfast correctly!${txtrst}"; delay; exit 0
	fi

	if [ ! -e $KERNSOURCE/arch ]; then
		echo "${bldred}----- ERROR: Linux source was not found!${txtrst}"; delay
		echo "${bldred}----- Please, download the source!${txtrst}"; delay; exit 0
	fi

	if [ ! -f ${CROSS_COMPILE}gcc ]; then
		echo "${bldred}----- ERROR: GCC was not found!${txtrst}"; delay; exit 0
		echo "${bldred}----- Please, download the GCC!${txtrst}"; delay; exit 0
	fi

	if [ ! -f $KERNFLASHABLE/META-INF/com/google/android/update-binary ]; then
		echo "${bldylw}----- WARNING: No output structure found!${txtrst}"; delay
		echo "${bldylw}----- Please, establish the output structure!${txtrst}"; delay
	fi

	echo "${bldgrn}----- SUCCESS: Source was checked!${txtrst}"; delay
}

# Clean leftover junk
clean_junk()
{
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

# Clean the BF tree
clean()
{
	echo "${bldcya}----- Cleaning up source...${txtrst}"; delay

	# Clean leftover junk
	cd $KERNSOURCE

	clean_junk

	# Clean the tree via main cleaning functions
	if [ -e $KERNSOURCE/Makefile ]; then
		make mrproper
		make clean
	fi

	cd $ROOTDIR

	# Clean leftover junk
	rm -rf $KERNSOURCE/arch/$ARCH/boot/*.dtb
	rm -rf $KERNSOURCE/arch/$ARCH/boot/*.cmd
	if [ "$ARCH" = "arm" ]; then
		rm -rf $KERNSOURCE/arch/arm/mach-msm/smd_rpc_sym.c
	fi
	rm -rf $KERNSOURCE/arch/$ARCH/crypto/aesbs-core.S
	rm -rf $KERNSOURCE/include/generated
	rm -rf $KERNSOURCE/arch/*/include/generated
	rm -rf $KERNIMG

	# Remove the built kernel
	rm -rf $KERNFLASHABLE/kernel/$IMGTYPE

	# Check the source after cleaning and print the result
	if [ ! -e $KERNSOURCE/scripts/basic/fixdep ]; then
		echo "${bldgrn}----- SUCCESS: Tree was successfully cleaned!${txtrst}"; delay
	else
		echo "${bldred}----- ERROR: Tree was not cleaned!${txtrst}"; delay; exit 0
	fi
}

# Complete cleaning of the tree
full_clean()
{
	# Clean leftover junk
	cd $KERNSOURCE
	clean_junk
	cd $ROOTDIR

	# Use clean() only if required
	if [ -e $KERNSOURCE/scripts/basic/fixdep ]; then
		clean
	else
		echo "${bldgrn}----- SUCCESS: Tree is already cleaned!${txtrst}"; delay
	fi
}

# Defconfig creator
crt_config()
{
	echo "${bldcya}----- Checking for defconfig...${txtrst}"; delay

	# Trap into the kernel source
	cd $KERNSOURCE

	# Create the config only if there is no one
	if [ ! -f $KERNSOURCE/arch/$ARCH/configs/$CONFIG ]; then
		echo "${bldcya}----- Creating defconfig...${txtrst}"; delay

		if [ ! -e $KERNSOURCE/arch/$ARCH/configs/$ORIGCONFIG ]; then
			echo "${bldred}----- ERROR: $ORIGCONFIG was not found!${txtrst}"; delay; exit 0
		fi

		if [ "$CONFIG" = "$ORIGCONFIG" ]; then
			echo "${bldred}----- ERROR: Configurations' names are the same!${txtrst}"; delay; exit 0
		fi

		make $ORIGCONFIG
		mv .config $KERNSOURCE/arch/$ARCH/configs/$CONFIG

		clean

		if [ -e $KERNSOURCE/arch/$ARCH/configs/$CONFIG ]; then
			echo "${bldgrn}----- SUCCESS: Defconfig was successfully created!${txtrst}"; delay
		else
			echo "${bldred}----- ERROR: Defconfig was not created!${txtrst}"; delay; exit 0
		fi
	else
		echo "${bldgrn}----- SUCCESS: Defconfig was found!${txtrst}"; delay
	fi

	# Go back to root
	cd $ROOTDIR
}

# Flashable archive creator
crt_flashable()
{
	echo "${bldcya}----- Creating flashable archive...${txtrst}"; delay

	# Trap into the flashable structure
	cd $KERNFLASHABLE

	# Remove all the prebuilt kernels
	rm -rf *.zip

	# Use VERSION as a name
	zip -r ${VERSION}-$(date +"%Y%m%d").zip .

	# Check the SOURCE dependency in output directory
	if [ ! -e $OUTPUT/$SOURCE/ ]; then
		mkdir -p $OUTPUT/$SOURCE/
	fi

	if [ ! -e $OUTPUT/archived/$SOURCE/ ]; then
		mkdir -p $OUTPUT/archived/$SOURCE/
	fi

	if [ -e $KERNFLASHABLE/${VERSION}*.zip ]; then
		if [ -e $OUTPUT/$SOURCE/${VERSION}*.zip ]; then
			mv -f $OUTPUT/$SOURCE/${VERSION}*.zip $OUTPUT/archived/$SOURCE
		fi

		mv $KERNFLASHABLE/${VERSION}*.zip $OUTPUT/$SOURCE/

		echo "${bldgrn}----- SUCCESS: Flashable archive was successfully created!${txtrst}"; delay
	else
		echo "${bldred}----- ERROR: Flashable archive was not created!${txtrst}"; delay; exit 0
	fi

	# Go back to root
	cd $KERNSOURCE
}

# Kernel creator (^_^)
crt_kernel() {
	echo "${bldcya}----- Building -> ${VERSION}${txtrst}"; delay

	# Trap into the kernel source
	cd $KERNSOURCE

	# Initialize the config and start the building
	make $CONFIG
	make -j$NR_CPUS $IMGTYPE

	# Check the presence of the compiled kernel image
	if [ -e $KERNIMG ]; then
		mv $KERNIMG $KERNFLASHABLE/kernel/

		crt_flashable
		clean

		if [ -e $OUTPUT/$SOURCE/$VERSION*.zip ]; then
			echo "${bldmgt}----- SUCCESS: Kernel was successfully built!${txtrst}"; delay
		else
			echo "${bldred}----- ERROR: Could not find the kernel!${txtrst}"; delay; exit 0
		fi
	else
		echo "${bldred}----- ERROR: Kernel STUCK in build!${txtrst}"; delay; exit 0
	fi
}

# Initialize the whole thing
init() {
	check
	crt_config

	echo "${bldblu}----- Build starts in 3${txtrst}"; sleep 1
	echo "${bldblu}----- Build starts in 2${txtrst}"; sleep 1
	echo "${bldblu}----- Build starts in 1${txtrst}"; sleep 1

	crt_kernel
}
