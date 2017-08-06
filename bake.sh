#!/bin/bash

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

# Specify breakfast core script directory
BFCORE="core/source.sh"
if [ -z $BFCORE ]; then
	echo "----- ERROR: Source file was not found!"
	echo "----- Please, ensure that you have $BFCORE script!"
	exit 1
else
	source $BFCORE
fi

echo "${bldcya}----- Starting Breakfast v$bf_ver...${txtrst}"; delay
[ ! "$1" == "--new" ] && config_loader

while [ $1 ]; do
	if [ "$1" == "--new" ]; then
		config_picker && config_loader
	elif [ "$1" == "--config" ]; then
		rm -f $KERNSOURCE/arch/$ARCH/configs/$CONFIG
		crt_config
	elif [ "$1" == "--fresh" ]; then
		rm -f $KERNSOURCE/arch/$ARCH/configs/$CONFIG
		crt_config && init
	elif [ "$1" == "--clean" ]; then
		intelli_clean "force"
	elif [ "$1" == "--destroy" ]; then
		rm -rf $OUTPUT/*
	else
		echo "${bldred}----- ERROR: Unknown key. Continuing...${txtrst}"; delay
		break
	fi

	exit 0
done

intelli_clean && init
