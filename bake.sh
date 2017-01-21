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

# Initialize BF source
source source.sh

# Start the script
echo "${bldcya}----- Starting Breakfast v$bf_ver...${txtrst}"; delay

# Use keys for better interaction
while [ 1 ]; do
	if [ "$1" = "--init" ]; then
		# Regenerate BF config
		rm -rf $BRKFSTCONFIGS/cur_config && config_picker
		exit 1
	elif [ "$1" = "--new" ]; then
		# Regenerate kernel defconfig and start the building
		config_loader
		rm -rf $KERNSOURCE/arch/$ARCH/configs/$CONFIG && crt_config
		init
		exit 1
	elif [ "$1" = "--config" ]; then
		# Regenerate kernel defconfig
		config_loader
		rm -rf $KERNSOURCE/arch/$ARCH/configs/$CONFIG && crt_config
		exit 1
	elif [ "$1" = "--clean" ]; then
		# Clean the tree
		config_loader
		full_clean
		exit 1
	elif [ "$1" = "--remove" ]; then
		# Remove all the built kernels
		rm -rf $OUTPUT/archived/*.zip
		rm -rf $OUTPUT/*.zip
		exit 1
	elif [ -z "$1" ]; then
		# Skip this structure if there is no key
		break
	else
		# Print ERROR if the key is undefined
		echo "${bldred}----- ERROR: Unknown key. Continuing...${txtrst}"; delay
		break
	fi
done

# Initialize the script
config_loader
hard_clean && full_clean
init

# End
exit 1
