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
bake_version=1.0

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

# Userspace configuration
# The name of the kernel
export KERNNAME=""
# Number of symbols after LOCALVERSION
export VCOUNT=""
# Target architecture
export ARCH=""
# Target subarchitecture (mostly the same as ARCH)
export SUBARCH=""
# Original defconfig, which will be used to create CONFIG
export ORIGCONFIG=""
# Configuration for the build
export CONFIG=""
# Cross-Compiler name
export CC_TYPE=""
# A type of image, that will be built
export IMGDATA=""
# Addons support
export ADDONS_ENABLED=false

# Hardcoded configuration
export KERNDIR=`readlink -f .`
export NR_CPUS=`grep 'processor' /proc/cpuinfo | wc -l`
export MAXFREQ=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_max_freq)
export OUTPUT="$KERNDIR/breakfast/output"
export IMG="$KERNDIR/arch/$ARCH/boot/$IMGDATA"
export CROSS_COMPILE="$KERNDIR/breakfast/toolchain/$CC_TYPE/bin/${CC_TYPE}-"
# If there is no config, than 'cat' would print a error. We do not want this
if [ -e $KERNDIR/arch/$ARCH/configs/$CONFIG ]; then
	export VERSION=$(cat $KERNDIR/arch/$ARCH/configs/$CONFIG | grep "CONFIG_LOCALVERSION=" | dd bs=1 skip=22 count=$VCOUNT 2>/dev/null)
fi

# Custom code can be placed here
# Do not forget to initialize 'addons' then
if [ $ADDONS_ENABLED = "true" ]; then
	addons()
	{
		empty
	}
fi

# Breakfast structure
crt_struct()
{
	if [ ! -e $KERNDIR/breakfast ]; then
		echo "${bldmgt}----- Welcome to breakfast!${txtrst}"; delay
		echo "${bldcya}----- Creating the structure...${txtrst}"; delay

		# Flashable archive structure
		mkdir -p $OUTPUT/META-INF/com/google/android
		mkdir -p $OUTPUT/core

		# GCC directory
		mkdir -p $KERNDIR/breakfast/toolchain

		# Check the created directories and print the result
		if [ -e $OUTPUT/META-INF/com/google/android ] && [ -e $OUTPUT/core ] && [ -e $KERNDIR/breakfast/toolchain ]; then
			echo "${bldgrn}----- SUCCESS: Build structure was successfully created!${txtrst}"; delay
		else
			echo "${bldred}----- ERROR: Could not create the structure!${txtrst}"; delay; exit
		fi
	fi
}

# Remove all the built stuff
hard_clean()
{
	# Remove kernel image from the tree
	if [ -e $IMG ]; then
		rm -rf $IMG
	fi

	# Remove kernel image from the flashable structure
	if [ -e $OUTPUT/core/$IMGDATA ]; then
		rm -rf $OUTPUT/core/$IMGDATA
	fi

	# Remove ready kernel archive
	if [ -e $OUTPUT/$KERNNAME*.zip ]; then
		rm -rf $OUTPUT/$KERNNAME*.zip
	fi
}

# Simple check for stuff
check()
{
	echo "${bldcya}----- Checking the source...${txtrst}"; delay

	# Check, if the linux tree is present
	if [ ! -e $KERNDIR/arch ]; then
		echo "${bldred}----- ERROR: No Linux source has been found!${txtrst}"; delay
		echo "${bldred}----- ERROR: Please, download the source and try again!${txtrst}"; delay; exit
	fi

	# Check, if the toolchain is present
	if [ ! -f ${CROSS_COMPILE}gcc ]; then
		echo "${bldred}----- ERROR: Cannot find GCC!${txtrst}"; delay; exit
	fi

	# Check, if the flashable structure is present
	if [ ! -f $OUTPUT/META-INF/com/google/android/update-binary ]; then
		echo "${bldylw}----- WARNING: No output structure found!${txtrst}"; delay
		echo "${bldred}----- WARNING: Please, establish the output structure!${txtrst}"; delay
	fi

	echo "${bldgrn}----- SUCCSESS: Source was checked!${txtrst}"; delay
}

# Clean leftover junk
clean_junk()
{
	# Find and remove unactive files via parallel
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

	# Remove junk files
	clean_junk

	# Clean the tree via base cleaning functions
	make mrproper
	make clean

	# Clean leftover files
	rm -rf $KERNDIR/arch/$ARCH/boot/*.dtb
	rm -rf $KERNDIR/arch/$ARCH/boot/*.cmd
	# 'mach-msm' directory is present on old ARM kernels
	if [ "$ARCH" = "arm" ]; then
		rm -rf $KERNDIR/arch/arm/mach-msm/smd_rpc_sym.c
	fi
	rm -rf $KERNDIR/arch/$ARCH/crypto/aesbs-core.S
	rm -rf $KERNDIR/include/generated
	rm -rf $KERNDIR/arch/*/include/generated
	rm -rf $IMG
	# Remove the built kernel
	rm -rf $OUTPUT/core/$IMGDATA

	# Check the source after cleaning and print the result
	if [ ! -e $KERNDIR/scripts/basic/fixdep ]; then
		echo "${bldgrn}----- SUCCESS: Successfully cleaned!${txtrst}"; delay
	else
		echo "${bldred}----- ERROR: Could not cleanup the tree!${txtrst}"; delay; exit
	fi
}

# Complete cleaning of the tree
full_clean()
{
	# Remove junk files
	clean_junk

	# Intelligent cleaning verification requirement
	if [ -e $KERNDIR/scripts/basic/fixdep ]; then
		# 'clean' function takes a while, so this check is needed
		clean
	else
		echo "${bldgrn}----- SUCCESS: Source is already cleaned!${txtrst}"; delay
	fi
}

# Defconfig creator
crt_conf()
{
	echo "${bldcya}----- Checking for defconfig...${txtrst}"; delay

	# Create the config only if there is no one
	if [ ! -f $KERNDIR/arch/$ARCH/configs/$CONFIG ]; then
		echo "${bldcya}----- Creating defconfig...${txtrst}"; delay

		# Break up, if there is no original defconfig
		if [ ! -e $KERNDIR/arch/$ARCH/configs/$ORIGCONFIG ]; then
			echo "${bldred}----- ERROR: Could not find an original defconfig!${txtrst}"; delay; exit
		fi

		# Created defconfig should not replace the original defconfig
		if [ $CONFIG = $ORIGCONFIG ]; then
			echo "${bldred}----- ERROR: Configs names are the same!${txtrst}"; delay; exit
		fi

		# Make an original defconfig and load in to the tree
		make $ORIGCONFIG
		mv .config $KERNDIR/arch/$ARCH/configs/$CONFIG

		# Clean the tree after this process
		clean

		# Check the tree and print the result
		if [ -e $KERNDIR/arch/$ARCH/configs/$CONFIG ]; then
			echo "${bldgrn}----- SUCCESS: Defconfig was successfully created!${txtrst}"; delay
		else
			echo "${bldred}----- ERROR: Could not create a defconfig!${txtrst}"; delay; exit
		fi
	else
		# There is no sense to do this if we already have a defconfig
		echo "${bldgrn}----- SUCCESS: Defconfig was found!${txtrst}"; delay
	fi
}

# Flashable archive creator
crt_flashable()
{
	echo "${bldcya}----- Creating archive...${txtrst}"; delay

	# Trap into flashable structure
	cd $OUTPUT

	# Remove all the prebuilt kernels
	rm -rf $KERNNAME*.zip

	# Use VERSION as a name, if it is defined
	if [ $VERSION ]; then
		zip -r ${VERSION}-$(date +"%d%m%Y").zip .
	else
		# If no, than simply use KERNNAME with the current date
		zip -r ${KERNNAME}-$(date +"%d%m%Y").zip .
	fi

	# Check the tree and print the result
	if [ $OUTPUT/$VERSION ] || [ $OUTPUT/$KERNNAME ]; then
		echo "${bldgrn}----- SUCCESS: Flashable archive was successfully created!${txtrst}"; delay
	else
		echo "${bldred}----- ERROR: Failed to create an archive!${txtrst}"; delay; exit
	fi

	# Go back to the root
	cd $KERNDIR
}

# Kernel creator (^_^)
build()
{
	echo "${bldcya}----- Building -> ${VERSION}${txtrst}"; delay

	# Initialize the config and start the building
	make $CONFIG
	make -j$NR_CPUS $IMGDATA

	# Check the presence of the compiled kernel image
	if [ -e $IMG ]; then
		# If there is one, that move it to the flashable structure
		mv $IMG $OUTPUT/core/

		# Create a flashable archive with compiled image
		crt_flashable
		# Clean the tree after this process
		clean

		# Check the tree and print the result
		if [ $OUTPUT/$VERSION ] || [ $OUTPUT/$KERNNAME ]; then
			echo "${bldmgt}----- Kernel was successfully built!${txtrst}"; delay
		else
			echo "${bldred}----- ERROR: Could not find the kernel!${txtrst}"; delay; exit
		fi
	else
		# If image was not found, than print this
		echo "${bldred}----- ERROR: Kernel STUCK in build!${txtrst}"; delay; exit
	fi
}

# Initial launch
init()
{
	# Do basic preparation before the building
	check
	crt_conf

	echo "${bldblu}----- Build starts in 3${txtrst}"; sleep 1
	echo "${bldblu}----- Build starts in 2${txtrst}"; sleep 1
	echo "${bldblu}----- Build starts in 1${txtrst}"; sleep 1

	# Then, start the building
	build
}

# Start the script
echo "${bldcya}----- Starting Breakfast v$bake_version...${txtrst}"; delay
# Check the presence of the Breakfast structure. If there is no, than create one
crt_struct
# Remove the files that could affect the build
hard_clean

# Check the performance of the host by simple calculations
if [ $NR_CPUS -le "4" ] && [ $MAXFREQ -le "2000000" ]; then
	echo "${bldylw}----- WARNING: Your PC is too weak!${txtrst}"; delay
	echo "${bldylw}----- WARNING: The build can take a couple of minutes${txtrst}"; delay
fi

# Use keys for better interaction
while [ 1 ]; do
	if [ "$1" = "--clean" ]; then
		# Simply clean the tree
		full_clean
		exit
	elif [ "$1" = "--config" ]; then
		# Regenerate defconfig
		rm -rf arch/$ARCH/configs/$CONFIG
		crt_conf
		exit
	elif [ -z "$1" ]; then
		# If there is no key, than just ignore this structure
		break
	else
		# If the key is undefined, than print it
		echo "${bldred}----- ERROR: Unknown key. Continuing...${txtrst}"; delay;
		break
	fi
done

# Initialize the script
full_clean
init

# Force kill the script
exit
