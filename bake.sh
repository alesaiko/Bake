#!/bin/bash

# Initialize breakfast source
source source.sh

# Start the script
echo "${bldcya}----- Starting Breakfast v$bake_version...${txtrst}"; delay

# Use keys for better interaction
while [ 1 ]; do
	if [ "$1" = "--clean" ]; then
		# Simply clean the tree
		config_loader
		full_clean
		exit
	elif [ "$1" = "--config" ]; then
		# Regenerate defconfig
		config_loader
		rm -rf $KERNSOURCE/arch/$ARCH/configs/$CONFIG
		crt_config
		exit
	elif [ "$1" = "--new" ]; then
		# Regenerate breakfast config
		rm -rf $BRKFSTCONFIGS/cur_config
		config_picker
		exit
	elif [ "$1" = "--remove" ]; then
		# Remove all the built kernels
		rm -rf $OUTPUT/archived/*.zip
		rm -rf $OUTPUT/*.zip
		exit
	elif [ -z "$1" ]; then
		# If there is no key, then just ignore this structure
		break
	else
		# If the key is undefined, then print it
		echo "${bldred}----- ERROR: Unknown key. Continuing...${txtrst}"; delay
		break
	fi
done

# Load the breakfast config
config_loader
# Remove the files that could affect the build
hard_clean

# Check the performance of the host by simple calculations
if [ $NR_CPUS -le "4" ] && [ $MAXFREQ -le "2000000" ]; then
	echo "${bldylw}----- WARNING: Your PC is too weak!${txtrst}"; delay
	echo "${bldylw}----- WARNING: The build can take a couple of minutes${txtrst}"; delay
fi

# Initialize the script
full_clean
init

# Force kill the script
exit 1
