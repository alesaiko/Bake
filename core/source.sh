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
bf_ver=2.3;

# Global delay
delay() {
	sleep 0.25;
}

# Colors support
export txtbld=$(tput bold);
export txtrst=$(tput sgr0);
export red=$(tput setaf 1);
export grn=$(tput setaf 2);
export ylw=$(tput setaf 3);
export blu=$(tput setaf 4);
export mgt=$(tput setaf 5);
export cya=$(tput setaf 6);
export bldred=${txtbld}$(tput setaf 1);
export bldgrn=${txtbld}$(tput setaf 2);
export bldylw=${txtbld}$(tput setaf 3);
export bldblu=${txtbld}$(tput setaf 4);
export bldmgt=${txtbld}$(tput setaf 5);
export bldcya=${txtbld}$(tput setaf 6);

# Root directory
export ROOTDIR=`readlink -f .`;

# Breakfast defines
export BFCONFIGS="$ROOTDIR/core/configs";
export OUTPUT="$ROOTDIR/output";

# Number of host's logic processors
export NR_CPUS=`grep 'processor' /proc/cpuinfo | wc -l`;

# Update current BF config
update_cur_config() {
	if [ -e $BFCONFIGS/.cur_config ]; then
		export CUR_CONFIG=$(cat $BFCONFIGS/.cur_config);
	fi
}; update_cur_config

# Load defines from BF config
load_defines() {
	export KERNSOURCE="$ROOTDIR/src/kernel/$SOURCE";
	export KERNFLASHABLE="$ROOTDIR/src/flashable/$FLASHABLE";
	export CROSS_COMPILE="$ROOTDIR/toolchain/$TOOLCHAIN/bin/${TOOLCHAIN}-";
	export KERNIMG="$KERNSOURCE/arch/$ARCH/boot/$IMGTYPE";
	export VERSION="$SOURCE";
}

# Check for stuff
check() {
	echo "${bldcya}----- Checking BF...${txtrst}"; delay;

	if [ ! -n $BFCONFIGS ]; then
		echo "${bldred}----- ERROR: Configuration directory was not found!${txtrst}"; delay;
		echo "${bldred}----- Please, ensure that you have installed Breakfast correctly!${txtrst}"; delay; exit 0;
	fi

	if [ ! -n $KERNSOURCE ]; then
		echo "${bldred}----- ERROR: Linux source was not found!${txtrst}"; delay;
		echo "${bldred}----- Please, download the source!${txtrst}"; delay; exit 0;
	fi

	if [ ! -f ${CROSS_COMPILE}gcc ]; then
		echo "${bldred}----- ERROR: Toolchain was not found!${txtrst}"; delay;
		echo "${bldred}----- Please, download the toolchain!${txtrst}"; delay; exit 0;
	fi

	if [ ! -f $KERNFLASHABLE/META-INF/com/google/android/update-binary ]; then
		echo "${bldylw}----- WARNING: No flashable structure found!${txtrst}"; delay;
		echo "${bldylw}----- Please, establish the flashable structure first!${txtrst}"; delay;
	fi

	echo "${bldgrn}----- SUCCESS: Source was checked!${txtrst}"; delay
}

# Pick BF config
config_picker() {
	if [ -n $BFCONFIGS ]; then
		# Display all available BF configs
		echo "${bldmgt}----- Available configs: ${txtrst}"; delay;
		ls $BFCONFIGS -1;

		# Display current BF config
		if [ -e $BFCONFIGS/.cur_config ] && [ $CUR_CONFIG ]; then
			echo "${bldmgt}----- Current config: ${txtrst}"; delay;
			echo $CUR_CONFIG;
		else
			echo "${bldylw}----- No config selected!${txtrst}"; delay;
		fi

		# Read config from input
		read -p "${bldmgt}----- Select the BF config: ${txtrst}" selected_config;
		if [ ! $selected_config ]; then
			echo "${bldylw}----- No config was selected!${txtrst}"; delay;
		fi
		export config_name="$selected_config";

		# Pick the selected BF config
		if [ -e $BFCONFIGS/$selected_config ] ||
		   [ -e $BFCONFIGS/${selected_config}.conf ]; then
			if [ -e $BFCONFIGS/${selected_config}.conf ]; then
				config_name="${selected_config}.conf";
			fi

			# Load the selected config
			echo "$config_name" > $BFCONFIGS/.cur_config; update_cur_config;

			if [ "$CUR_CONFIG" = "$config_name" ]; then
				echo "${bldgrn}----- SUCCESS: $config_name was picked!${txtrst}"; delay;
			else
				echo "${bldred}----- ERROR: $config_name was not picked!${txtrst}"; delay exit 0;
			fi
		else
			echo "${bldred}----- ERROR: $config_name was not found!${txtrst}"; delay;
			echo "${bldred}----- Please, check out config name and try again!${txtrst}"; delay; exit 0;
		fi
	else
		echo "${bldred}----- ERROR: Configuration directory was not found!${txtrst}"; delay;
		echo "${bldred}----- Please, ensure that you have installed Breakfast correctly!${txtrst}"; delay; exit 0;
	fi
}

# Load the BF config
config_loader() {
	if [ -n $BFCONFIGS ]; then
		# Pick BF config
		update_cur_config;
		if [ ! $CUR_CONFIG ]; then
			echo "${bldylw}----- WARNING: cur_config is empty!${txtrst}"; delay;
			echo "${bldylw}----- Calling config_picker()...${txtrst}"; delay;
			config_picker;
		fi

		# Load data from config
		source $BFCONFIGS/$CUR_CONFIG; load_defines;

		if [ $SOURCE ] && [ $ARCH ] && [ $SUBARCH ] && [ $ORIGCONFIG ] &&
		   [ $CONFIG ] && [ $TOOLCHAIN ] && [ $IMGTYPE ] && [ $FLASHABLE ] &&
		   [ $KERNSOURCE ] && [ $KERNFLASHABLE ] && [ $CROSS_COMPILE ] &&
		   [ $KERNIMG ] && [ $VERSION ]; then
			echo "${bldgrn}----- SUCCESS: $CUR_CONFIG was loaded!${txtrst}"; delay;
		else
			echo "${bldred}----- ERROR: $CUR_CONFIG was not loaded!${txtrst}"; delay; exit 0;
		fi
	else
		echo "${bldred}----- ERROR: Configuration directory was not found!${txtrst}"; delay;
		echo "${bldred}----- Please, ensure that you have installed Breakfast correctly!${txtrst}"; delay; exit 0;
	fi
}

# Remove built images
hard_clean() {
	if [ -n $KERNSOURCE ]; then
		rm -f $KERNIMG >> /dev/null;
		rm -f $KERNFLASHABLE/kernel/$IMGTYPE >> /dev/null;
	else
		echo "${bldred}----- ERROR: Linux source was not found!${txtrst}"; delay;
		echo "${bldred}----- Please, download the source!${txtrst}"; delay; exit 0;
	fi
}

# Clean leftover junk
clean_junk() {
	if [ -n $KERNSOURCE ]; then
		find $KERNSOURCE -type f \( -iname \*.rej	\
			       -o -iname \*.orig		\
			       -o -iname \*.bkp			\
			       -o -iname \*.ko			\
			       -o -iname \*.c.BACKUP.[0-9]*.c	\
			       -o -iname \*.c.BASE.[0-9]*.c	\
			       -o -iname \*.c.LOCAL.[0-9]*.c	\
			       -o -iname \*.c.REMOTE.[0-9]*.c	\
			       -o -iname \*.org \)		\
					| parallel rm -fv {};
	else
		echo "${bldred}----- ERROR: Linux source was not found!${txtrst}"; delay;
		echo "${bldred}----- Please, download the source!${txtrst}"; delay; exit 0;
	fi
}

# Clean BF tree
clean() {
	echo "${bldcya}----- Cleaning up the source...${txtrst}"; delay;

	if [ -n $KERNSOURCE ]; then
		# Clean the tree via main cleaning functions
		if [ -e $KERNSOURCE/Makefile ]; then
			# Trap into the tree and make a cleanup
			cd $KERNSOURCE;

			make mrproper;
			make clean;

			cd $ROOTDIR;
		fi

		# Clean leftover junk
		clean_junk;

		# Remove built images
		hard_clean;

		if [ "$ARCH" = "arm" ]; then
			rm -f $KERNSOURCE/arch/arm/mach-msm/smd_rpc_sym.c >> /dev/null;
		fi
		rm -rf $KERNSOURCE/arch/$ARCH/boot/*.dtb >> /dev/null;
		rm -rf $KERNSOURCE/arch/$ARCH/boot/*.cmd >> /dev/null;
		rm -f $KERNSOURCE/arch/$ARCH/crypto/aesbs-core.S >> /dev/null;
		rm -rf $KERNSOURCE/include/generated >> /dev/null;
		rm -rf $KERNSOURCE/arch/*/include/generated >> /dev/null;

		# Check the source after cleaning
		if [ ! -e $KERNSOURCE/scripts/basic/fixdep ]; then
			echo "${bldgrn}----- SUCCESS: Tree was successfully cleaned!${txtrst}"; delay;
		else
			echo "${bldred}----- ERROR: Tree was not cleaned!${txtrst}"; delay; exit 0;
		fi
	else
		echo "${bldred}----- ERROR: Linux source was not found!${txtrst}"; delay;
		echo "${bldred}----- Please, download the source!${txtrst}"; delay; exit 0;
	fi
}

# Completely clean the tree
full_clean() {
	if [ -n $KERNSOURCE ]; then
		# Clean leftover junk
		clean_junk;

		# Remove built images
		hard_clean;

		# Use clean() only if required
		if [ -e $KERNSOURCE/scripts/basic/fixdep ]; then
			if [ -f $KERNSOURCE/arch/$ARCH/configs/$CONFIG ] || [ $1 ]; then
				clean;
			else
				echo "${bldylw}----- WARNING: Defconfig hasn't been created yet!${txtrst}"; delay;
				echo "${bldylw}----- Skipping the cleaning...${txtrst}"; delay;
			fi
		else
			echo "${bldgrn}----- SUCCESS: Tree is already cleaned!${txtrst}"; delay;
		fi
	else
		echo "${bldred}----- ERROR: Linux source was not found!${txtrst}"; delay;
		echo "${bldred}----- Please, download the source!${txtrst}"; delay; exit 0;
	fi
}

# Create a defconfig
crt_config() {
	echo "${bldcya}----- Checking for defconfig...${txtrst}"; delay;

	# Create the config only if there is no one
	if [ -n $KERNSOURCE ]; then
		if [ ! -f $KERNSOURCE/arch/$ARCH/configs/$CONFIG ]; then
			echo "${bldcya}----- Creating defconfig...${txtrst}"; delay;

			if [ ! -e $KERNSOURCE/arch/$ARCH/configs/$ORIGCONFIG ]; then
				echo "${bldred}----- ERROR: $ORIGCONFIG was not found!${txtrst}"; delay; exit 0;
			fi

			if [ "$CONFIG" = "$ORIGCONFIG" ]; then
				echo "${bldred}----- ERROR: Configurations' names are same!${txtrst}"; delay; exit 0;
			fi

			# Trap into the tree and make a defconfig
			cd $KERNSOURCE;

			make $ORIGCONFIG;
			mv $KERNSOURCE/.config $KERNSOURCE/arch/$ARCH/configs/$CONFIG;

			cd $ROOTDIR;

			# Clean the tree after proccess
			clean;

			if [ -e $KERNSOURCE/arch/$ARCH/configs/$CONFIG ]; then
				echo "${bldgrn}----- SUCCESS: Defconfig was successfully created!${txtrst}"; delay;
			else
				echo "${bldred}----- ERROR: Defconfig was not created!${txtrst}"; delay; exit 0;
			fi
		else
			echo "${bldgrn}----- SUCCESS: Defconfig was found!${txtrst}"; delay;
		fi
	else
		echo "${bldred}----- ERROR: Linux source was not found!${txtrst}"; delay;
		echo "${bldred}----- Please, download the source!${txtrst}"; delay; exit 0;
	fi
}

# Create a flashable archive
crt_flashable() {
	echo "${bldcya}----- Creating flashable archive...${txtrst}"; delay;

	if [ -e $KERNFLASHABLE ]; then
		# Trap into the flashable structure
		cd $KERNFLASHABLE;

		# Remove all the prebuilt kernels
		rm -rf *.zip >> /dev/null;

		# Use VERSION as a name
		zip -r ${VERSION}-$(date +"%Y%m%d").zip .

		# Check the SOURCE dependency in output directory
		if [ ! -e $OUTPUT/$SOURCE/ ]; then
			mkdir -p $OUTPUT/$SOURCE/;
		fi

		if [ ! -e $OUTPUT/archived/$SOURCE/ ]; then
			mkdir -p $OUTPUT/archived/$SOURCE/;
		fi

		# Check every step of the archive creation
		if [ -e $KERNFLASHABLE/${VERSION}*.zip ]; then
			if [ -e $OUTPUT/$SOURCE/${VERSION}*.zip ]; then
				mv -f $OUTPUT/$SOURCE/${VERSION}*.zip $OUTPUT/archived/$SOURCE;
			fi

			mv $KERNFLASHABLE/${VERSION}*.zip $OUTPUT/$SOURCE/;

			if [ -e $OUTPUT/$SOURCE/${VERSION}*.zip ]; then
				echo "${bldgrn}----- SUCCESS: Flashable archive was successfully created!${txtrst}"; delay;
			else
				echo "${bldred}----- ERROR: Flashable archive was not created!${txtrst}"; delay; exit 0;
			fi
		else
			echo "${bldred}----- ERROR: Flashable archive was not created!${txtrst}"; delay; exit 0;
		fi

		# Go back to root
		cd $KERNSOURCE;
	else
		echo "${bldred}----- ERROR: No flashable structure found!${txtrst}"; delay;
		echo "${bldred}----- Please, establish the flashable structure first!${txtrst}"; delay; exit 0;
	fi
}

# Kernel creator (^_^)
crt_kernel() {
	echo "${bldcya}----- Building -> ${VERSION}${txtrst}"; delay;

	if [ -n $KERNSOURCE ]; then
		# Start the timer
		time1=$(date +"%s.%N");

		# Trap into the kernel source
		cd $KERNSOURCE;

		# Initialize the config and start the building
		make $CONFIG;
		make -j$NR_CPUS $IMGTYPE;

		# Check the presence of the compiled kernel image
		if [ -e $KERNIMG ]; then
			mv $KERNIMG $KERNFLASHABLE/kernel/;

			crt_flashable;
			clean;

			if [ -e $OUTPUT/$SOURCE/${VERSION}*.zip ]; then
				echo "${bldmgt}----- SUCCESS: Kernel was successfully built!${txtrst}"; delay;
			else
				echo "${bldred}----- ERROR: Could not find the kernel!${txtrst}"; delay; exit 0;
			fi
		else
			echo "${bldred}----- ERROR: Kernel STUCK in build!${txtrst}"; delay; exit 0;
		fi

		# End the timer
		time2=$(date +"%s.%N");
		elapsed_time=$(echo "scale=1; ($time2 - $time1) / 1" | bc);

		echo "${bldcya}----- Elapsed time: $elapsed_time seconds${txtrst}"; delay;
	else
		echo "${bldred}----- ERROR: Linux source was not found!${txtrst}"; delay;
		echo "${bldred}----- Please, download the source!${txtrst}"; delay; exit 0;
	fi
}

# Initialize the whole thing
init() {
	check;
	crt_config;

	echo "${bldblu}----- Build starts in 3${txtrst}"; sleep 1;
	echo "${bldblu}----- Build starts in 2${txtrst}"; sleep 1;
	echo "${bldblu}----- Build starts in 1${txtrst}"; sleep 1;

	crt_kernel;
}
