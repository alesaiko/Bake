#!/bin/bash
reset

# Copyright (C) 2017, Alex Saiko <solcmdr@gmail.com>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License version 2 and
# only version 2 as published by the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.

bf_ver=2.4.1

delay() {
	sleep 0.2
}

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

export ROOTDIR=$(readlink -f .)
export BFCONFIGS="$ROOTDIR/core/configs"
export OUTPUT="$ROOTDIR/output"

export NR_CPUS=$(grep 'processor' /proc/cpuinfo | wc -l)
[ $NR_CPUS -le "8" ] && NR_CPUS="8"

update_cur_config() {
	if [ -e $BFCONFIGS/.cur_config ]; then
		export CUR_CONFIG=$(cat $BFCONFIGS/.cur_config 2>/dev/null)
	fi
}; update_cur_config

config_picker() {
	echo "${bldmgt}----- Available configs: ${txtrst}"; delay
	ls $BFCONFIGS -1

	if [ ! -z $CUR_CONFIG ]; then
		echo "${bldmgt}----- Current config: ${txtrst}"; delay
		echo $CUR_CONFIG
	else
		echo "${bldylw}----- No config selected!${txtrst}"; delay
	fi

	read -p "${bldmgt}----- Select the config: ${txtrst}" selected_config
	if [ -z $selected_config ]; then
		echo "${bldylw}----- No config selected!${txtrst}"; delay
		exit 0
	fi
	export config_name=$(find $BFCONFIGS/$selected_config* -printf "%f\n" -quit)

	if [ ! -z $config_name ]; then
		echo "$config_name" > $BFCONFIGS/.cur_config
		update_cur_config

		if [ "$CUR_CONFIG" = "$config_name" ]; then
			echo "${bldgrn}----- $config_name was successfully picked!${txtrst}"; delay
		else
			echo "${bldred}----- ERROR: $config_name was not picked!${txtrst}"; delay
			exit 1
		fi
	else
		echo "${bldred}----- ERROR: $config_name was not found!${txtrst}"; delay
		echo "${bldred}----- Please, check out the config and try again!${txtrst}"; delay
		exit 1
	fi
}

load_defines() {
	export KERNSOURCE="$ROOTDIR/src/kernel/$SOURCE"
	export KERNFLASHABLE="$ROOTDIR/src/flashable/$FLASHABLE"
	export CROSS_COMPILE="$ROOTDIR/toolchains/$TOOLCHAIN/bin/${TOOLCHAIN}-"
	export KERNIMG="$KERNSOURCE/arch/$ARCH/boot/$IMGTYPE"
	export VERSION="$SOURCE"
}

config_loader() {
	if [ -z $CUR_CONFIG ]; then
		echo "${bldylw}----- WARNING: cur_config is empty!${txtrst}"; delay
		echo "${bldylw}----- Calling config_picker...${txtrst}"; delay
		config_picker
	fi

	source $BFCONFIGS/$CUR_CONFIG && load_defines
	if [ -z $SOURCE ] || [ -z $ARCH ] || [ -z $SUBARCH ] ||
	   [ -z $ORIGCONFIG ] || [ -z $CONFIG ] || [ -z $TOOLCHAIN ] ||
	   [ -z $IMGTYPE ] || [ -z $FLASHABLE ] || [ -z $KERNSOURCE ] ||
	   [ -z $KERNFLASHABLE ] || [ -z $CROSS_COMPILE ] || [ -z $KERNIMG ] ||
	   [ -z $VERSION ]; then
		echo "${bldred}----- ERROR: $CUR_CONFIG was not loaded!${txtrst}"; delay
		exit 1
	fi
}

clean_leftover() {
	find $KERNSOURCE -type f \( -iname \*.rej		\
				 -o -iname \*.orig		\
				 -o -iname \*.bkp		\
				 -o -iname \*.ko		\
				 -o -iname \*.c.BACKUP.[0-9]*.c	\
				 -o -iname \*.c.BASE.[0-9]*.c	\
				 -o -iname \*.c.LOCAL.[0-9]*.c	\
				 -o -iname \*.c.REMOTE.[0-9]*.c	\
				 -o -iname \*.org \)		\
					| parallel rm -fv {}

	rm -f $KERNIMG $KERNFLASHABLE/kernel/$IMGTYPE
}

clean() {
	echo "${bldcya}----- Cleaning the source...${txtrst}"; delay

	if [ -e $KERNSOURCE/Makefile ]; then
		cd $KERNSOURCE
		make mrproper && make clean
		cd $ROOTDIR
	fi

	clean_leftover

	if [ "$ARCH" == "arm" ] && [ ! $CUR_CONFIG == "flo.conf" ]; then
		rm -f $KERNSOURCE/arch/arm/mach-msm/smd_rpc_sym.c
	fi

	rm -rf $KERNSOURCE/arch/$ARCH/boot/*.dtb		\
	       $KERNSOURCE/arch/$ARCH/boot/*.cmd		\
	       $KERNSOURCE/arch/$ARCH/crypto/aesbs-core.S	\
	       $KERNSOURCE/include/generated			\
	       $KERNSOURCE/arch/*/include/generated

	if [ -e $KERNSOURCE/scripts/basic/fixdep ]; then
		echo "${bldred}----- ERROR: Tree was not cleaned!${txtrst}"; delay
		exit 1
	fi
}

intelli_clean() {
	clean_leftover

	if [ -e $KERNSOURCE/scripts/basic/fixdep ] || [ "$1" == "force" ]; then
		clean
	fi
}

crt_config() {
	echo "${bldcya}----- Checking for defconfig...${txtrst}"; delay

	if [ ! -f $KERNSOURCE/arch/$ARCH/configs/$CONFIG ]; then
		echo "${bldcya}----- Creating defconfig...${txtrst}"; delay

		if [ ! -e $KERNSOURCE/arch/$ARCH/configs/$ORIGCONFIG ]; then
			echo "${bldred}----- ERROR: $ORIGCONFIG was not found!${txtrst}"; delay
			exit 1
		fi

		if [ "$CONFIG" == "$ORIGCONFIG" ]; then
			echo "${bldred}----- ERROR: Configurations' names are same!${txtrst}"; delay
			exit 1
		fi

		cd $KERNSOURCE && make $ORIGCONFIG

		if [ -e $KERNSOURCE/.config ]; then
			mv $KERNSOURCE/.config $KERNSOURCE/arch/$ARCH/configs/$CONFIG
		else
			echo "${bldred}----- ERROR: Generated .config disappeared!${txtrst}"; delay
			exit 1
		fi

		cd $ROOTDIR && clean
	fi
}

crt_flashable() {
	echo "${bldcya}----- Creating flashable archive...${txtrst}"; delay

	cd $KERNFLASHABLE

	rm -f *.zip

	export DATE=$(date +"%Y%m%d")
	zip -r ${VERSION}-$DATE.zip .

	[ ! -e $OUTPUT/$SOURCE/ ] && mkdir -p $OUTPUT/$SOURCE/
	[ ! -e $OUTPUT/archived/$SOURCE/ ] && mkdir -p $OUTPUT/archived/$SOURCE/

	if [ -e $KERNFLASHABLE/${VERSION}-$DATE.zip ]; then
		if [ -e $OUTPUT/$SOURCE/$VERSION*.zip ]; then
			mv -f $OUTPUT/$SOURCE/$VERSION*.zip $OUTPUT/archived/$SOURCE
		fi

		mv $KERNFLASHABLE/${VERSION}-$DATE.zip $OUTPUT/$SOURCE/

		if [ ! -e $OUTPUT/$SOURCE/${VERSION}-$DATE.zip ]; then
			echo "${bldred}----- ERROR: Flashable archive was not created!${txtrst}"; delay
			exit 1
		fi
	else
		echo "${bldred}----- ERROR: Flashable archive was not created!${txtrst}"; delay
		exit 1
	fi

	cd $ROOTDIR
}

crt_kernel() {
	echo "${bldcya}----- Building -> ${VERSION}${txtrst}"; delay

	if [ -n $KERNSOURCE ]; then
		time1=$(date +"%s.%N")

		cd $KERNSOURCE

		make $CONFIG && make -j$NR_CPUS $IMGTYPE

		if [ -e $KERNIMG ]; then
			mv $KERNIMG $KERNFLASHABLE/kernel/

			crt_flashable && clean

			if [ -e $OUTPUT/$SOURCE/$VERSION-$DATE.zip ]; then
				echo "${bldmgt}----- Kernel was successfully built!${txtrst}"; delay
			else
				echo "${bldred}----- ERROR: Could not find the built kernel!${txtrst}"; delay
				exit 1
			fi
		else
			echo "${bldred}----- ERROR: Kernel STUCK in build!${txtrst}"; delay
			exit 1
		fi

		time2=$(date +"%s.%N")
		elapsed_time=$(echo "scale=1; ($time2 - $time1) / 1" | bc)

		echo "${bldcya}----- Elapsed time: $elapsed_time seconds${txtrst}"; delay
	else
		echo "${bldred}----- ERROR: Linux source was not found!${txtrst}"; delay
		echo "${bldred}----- Please, download Linux source!${txtrst}"; delay
		exit 1
	fi
}

init() {
	crt_config

	echo "${bldblu}----- Build starts in 3${txtrst}"; sleep 1
	echo "${bldblu}----- Build starts in 2${txtrst}"; sleep 1
	echo "${bldblu}----- Build starts in 1${txtrst}"; sleep 1

	crt_kernel
}
