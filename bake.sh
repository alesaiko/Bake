#!/bin/bash

#
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
#

if [ -e core/source.sh ]; then
	source core/source.sh
else
	echo "$(tput bold)$(tput setaf 1)ERROR: SOURCE FILE WAS NOT FOUND!$(tput sgr0)"; exit 1
fi

echo "${bldcya}----- Starting Breakfast v$bf_ver...${txtrst}"; delay;

if [ ! "$1" == "--new" ]; then
	config_loader
fi

while [ $1 ]; do
	if [ "$1" == "--new" ]; then
		config_picker
		config_loader
	elif [ "$1" == "--config" ]; then
		rm -f $KERNSOURCE/arch/$ARCH/configs/$CONFIG
		crt_config
	elif [ "$1" == "--fresh" ]; then
		rm -f $KERNSOURCE/arch/$ARCH/configs/$CONFIG
		crt_config
		init
	elif [ "$1" == "--clean" ]; then
		full_clean "force"
	elif [ "$1" == "--destroy" ]; then
		rm -rf $OUTPUT/archived/*.zip \
		       $OUTPUT/*.zip
	else
		echo "${bldred}----- ERROR: Unknown key. Continuing...${txtrst}"; delay
		break
	fi

	exit 0
done

full_clean
init

exit 0
