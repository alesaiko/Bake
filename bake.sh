#!/bin/bash

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

# Initialize Breakfast source
if [ -e core/source.sh ]; then
	source core/source.sh;
else
	echo "$(tput bold)$(tput setaf 1)ERROR: SOURCE FILE WAS NOT FOUND!$(tput sgr0)"; exit 0;
fi

echo "${bldcya}----- Starting Breakfast v$bf_ver...${txtrst}"; delay;

# Keys support
while [ 1 ]; do
	# Initialize Breakfast configuration file
	if [ "$1" = "--new" ]; then
		config_picker;
		exit 1;
	# Build the kernel with a new defconfig
	elif [ "$1" = "--fresh" ]; then
		config_loader;
		rm -rf $KERNSOURCE/arch/$ARCH/configs/$CONFIG && crt_config;
		init;
		exit 1;
	# Regenerate kernel defconfig
	elif [ "$1" = "--config" ]; then
		config_loader;
		rm -rf $KERNSOURCE/arch/$ARCH/configs/$CONFIG && crt_config;
		exit 1;
	# Clean up the tree
	elif [ "$1" = "--clean" ]; then
		config_loader;
		full_clean force;
		exit 1;
	# Remove all output archives
	elif [ "$1" = "--remove" ]; then
		rm -rf $OUTPUT/archived/*.zip;
		rm -rf $OUTPUT/*.zip;
		exit 1;
	elif [ -z "$1" ]; then
		break;
	else
		echo "${bldred}----- ERROR: Unknown key. Continuing...${txtrst}"; delay;
		break;
	fi
done

# Initialize the script
config_loader;
full_clean;
init;

# End of the script
exit 1;
