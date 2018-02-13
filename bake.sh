#!/bin/bash
clear

# Copyright (C) 2017-2018, Alex Saiko <solcmdr@gmail.com>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License version 2 and
# only version 2 as published by the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.

BFVER=3.2

# Initial terminal color plan.
REDCL=$(tput bold)$(tput setaf 1)
GRNCL=$(tput bold)$(tput setaf 2)
BLUCL=$(tput bold)$(tput setaf 4)
MGTCL=$(tput bold)$(tput setaf 5)
CYACL=$(tput bold)$(tput setaf 6)
# A flag to reset all applied colors.
RSTCL=$(tput sgr0)

# Current directory represents the directory where this script has been called.
# Root directory represents the directory where this script is located.
CRDIR=$(pwd)
RTDIR=$(cd $(dirname ${BASH_SOURCE[0]}) && pwd)
CFDIR="$RTDIR/configs"
KNDIR="$RTDIR/kernels"
SADIR="$RTDIR/signapk"
FSDIR="$RTDIR/flashables"
FSTMP="$FSDIR/.tmp"
BINST="$FSDIR/breakfast-installer"
TCDIR="$RTDIR/toolchains"
OPDIR="$RTDIR/outputs"

# Bake uses the number of threads which is equal to the doubled
# num of virtual processors to boost the compilation.
NRCPS=$[ $(grep "processor" /proc/cpuinfo | wc -l) * 2 ]

# Automatical Git tagging support.
AUTAG="true"
TAGNM="breakfast"

# A simple color-expecting print function with a 0.125 delay for smooth output
# of concurrent prints.
print() { printf "${1}$RSTCL\n"; sleep 0.125; }

terminate()
{
	case "$1" in
	0) error="Bake is damaged!\n- Broken part --> $2";;
	1) error="No argument passed!";;
	2) error="$2 was not found!";;
	3) error="$2 was not loaded!";;
	4) error="Kernel stuck in build!";;
	5) error="Failed to create flashable archive!";;
	6) error="I/O failure!";;
	*) error="Unknown error!";;
	esac

	# Remove temporary flashable directory as it will be overwritten anyway.
	rm -rf $FSTMP

	print "${REDCL}- ERROR: $error\n\nScript terminated with error $1!" &&
	# Print uses a 0.125 seconds delay, hence 2.875 should be used here to
	# provide overall 3 seconds delay before the exit.
	sleep 2.875
	exit $1
}

prepare_environment()
{
	print "${CYACL}- Preparing working environment..."
	# Unset all the required variables to avoid the conflict.
	for var in ARCH SUBARCH KNAME KTYPE DFCFG TOOLC; do unset $var; done
}

config_loaded()
{
	# Check whether all the required variables are actually set.
	[ ! -z $ARCH ] && [ ! -z $SUBARCH ] && [ ! -z $KNAME ] &&
	[ ! -z $KTYPE ] && [ ! -z $DFCFG ] && [ ! -z $TOOLC ] &&
	[ ! -z $CROSS_COMPILE ] || return 1

	return 0
}

load_config()
{
	# This function expects an argument to be passed.
	[ ! -z $1 ] || terminate "1"

	# Try to find a requested configuration in an appropriate directory.
	CRCFG=$(find $CFDIR/$1* -printf "%f\n" -quit 2>/dev/null)
	[ ! -z $CRCFG ] || terminate "2" "$1"

	print "${MGTCL}- Loading new Bake configuration --> $CRCFG..."
	# Prepare bash environment before sourcing the configuration file.
	prepare_environment

	# Load information from configuration file to bash environment and
	# setup cross compiler path.
	source ${CFDIR}/$CRCFG &&
	export CROSS_COMPILE="$TCDIR/$TOOLC/bin/${TOOLC}-"

	# Ensure all the things have been made properly.
	print "${MGTCL}- Validating Bake configuration..."
	(config_loaded) || terminate "3" "$CRCFG"

	print "${GRNCL}- $CRCFG was successfully loaded!"
}

prepare_kernel_tree()
{
	# This function cannot work without a configuration loaded.
	(config_loaded) || terminate "3" "Bake configuration"

	# Ensure there is a work-ready kernel tree.
	[ -f $KNDIR/$KNAME/Makefile ] && cd $KNDIR/$KNAME ||
	terminate "2" "$KNDIR/$KNAME/Makefile"

	print "${CYACL}- Preparing ${KNAME} tree..."

	# Do basic clean-up of the tree via Makefile-provided methods.
	[ -f scripts/basic/fixdep ] && (make clean mrproper)

	# Remove leftovers of the compilation.
	rm -rf arch/$ARCH/boot/*.dtb		\
	       arch/$ARCH/boot/*.cmd		\
	       arch/$ARCH/crypto/aesbs-core.S	\
	       arch/*/include/generated		\
	       include/generated

	# Try to remove *unneeded* files via parallel if supported.
	which parallel &>/dev/null
	[ "$?" -eq "0" ] &&
	find . -type f \( -iname \*.rej			\
		       -o -iname \*.orig		\
		       -o -iname \*.bkp			\
		       -o -iname \*.ko			\
		       -o -iname \*.c.BACKUP.[0-9]*.c	\
		       -o -iname \*.c.BASE.[0-9]*.c	\
		       -o -iname \*.c.LOCAL.[0-9]*.c	\
		       -o -iname \*.c.REMOTE.[0-9]*.c	\
		       -o -iname \*.org \)		\
				| parallel rm -fv { }

	# Tree-specific clean-ups.
	case "$CRCFG" in
	"hammerhead.conf") rm -f arch/$ARCH/mach-msm/smd_rpc_sym.c;;
	esac

	cd $CRDIR
}

sign_flashable()
{
	# This function expects both a configuration to be loaded and
	# an argument to be passed.
	(config_loaded) || terminate "3" "Bake configuration"
	[ ! -z $1 ] || terminate "1"

	# Check the presence of the required files.
	[ -f $SADIR/signapk.jar ] && [ -f $SADIR/keys/*.pk8 ] &&
	[ -f $SADIR/keys/*.pem ] && [ -f $FSTMP/$1 ] || return 1

	print "${CYACL}- Signing $1 archive..."

	# Setup private and public keys.
	PVKEY=$(find $SADIR/keys/*.pk8 | head -1)
	PBKEY=$(find $SADIR/keys/*.pem | head -1)

	# Sign a target flashable archive with previously set keys.
	java -jar $SADIR/signapk.jar $PBKEY $PVKEY $FSTMP/$1 $SADIR/$1

	# Move a signed archive back to the source.
	mv -f $SADIR/$1 $FSTMP/$1

	print "${GRNCL}- $1 was successfully signed!"
}

__make_kernel()
{
	# This function expects configuration to be loaded.
	(config_loaded) || terminate "3" "Bake configuration"

	# Clean-up the working tree and ensure there is one.
	prepare_kernel_tree

	# Trap into kernel tree as it is guaranteed to exist because of
	# the previous call.
	cd $KNDIR/$KNAME

	# Try to grab Git branch and export it to bash environment.
	[ -e $KNDIR/$KNAME/.git ] &&
	BRANCH=$(git rev-parse --abbrev-ref HEAD) || BRANCH="unstated"

	print "${CYACL}- Building ${KNAME} (\"$BRANCH\" branch)..."
	# Use generic 3 seconds delay before the build to start.
	for ((i = 3; i > 0; i--)); do
		print "${BLUCL}- Build starts in $i"; sleep 0.875
	done

	# Forcefully tag Git repository if specified.
	[ $AUTAG == "true" ] && git tag -afm "$TAGNM" $TAGNM &>/dev/null

	# Start the compilation with NRCPS number of threads using a
	# set-by-config cross compiler. ccache usage should be declared in
	# device-configuration file.
	make $DFCFG && make -j$NRCPS $KTYPE REAL_CC="$CACHE ${CROSS_COMPILE}gcc"

	# Ensure the kernel has been compiled succssfully.
	[ -f $KNDIR/$KNAME/arch/$ARCH/boot/$KTYPE ] &&
	print "${GRNCL}- $KNAME was successfully built!" || terminate "4"

	cd $CRDIR
}

__make_flashable()
{
	# This function expects configuration to be loaded.
	(config_loaded) || terminate "3" "Bake configuration"

	print "${CYACL}- Creating flashable kernel..."

	# Ensure all the required directories and files are actually set up.
	[ -s $BINST ] || terminate "2" "$BINST"
	[ -s $FSDIR/$KNAME ] || terminate "2" "$FSDIR/$KNAME"
	[ -s $KNDIR/$KNAME/arch/$ARCH/boot/$KTYPE ] ||
	terminate "2" "$KNDIR/$KNAME/arch/$ARCH/boot/$KTYPE"

	# Regenerate temporary directory for flashable structure.
	rm -rf $FSTMP && mkdir $FSTMP

	# Extract both Breakfast installer and device-specific data to the
	# temporary directory and check whether it all had been made correctly.
	cp -ax $BINST/* $FSTMP && cp -ax $FSDIR/$KNAME/* $FSTMP/kernel
	[ -f $FSTMP/kernel/config.sh ] || terminate "2" "$FSTMP/kernel"

	# Move freshly generated kernel image to the temporary directory.
	mv -f $KNDIR/$KNAME/arch/$ARCH/boot/$KTYPE $FSTMP/kernel/$KTYPE

	# Acquire the current date in Year-Month-Day format.
	DATE=$(date +"%Y%m%d")

	# Try to create a zipped archive with all the data collected in
	# temporary directory. Terminate early in case of a failure.
	cd $FSTMP && zip -r ${KNAME}-$DATE.zip .
	[ "$?" -eq "0" ] && cd $CRDIR || terminate "6"

	# Try to sign the newly created flashable archive with the keys created
	# by OpenSSL software. If the keys are absent, nothing will really
	# happen, hence this call is safe from all sides.
	sign_flashable "${KNAME}-$DATE.zip"

	# Clean-up the kernel-ready directory first. Move all the archives
	# placed within into a special "archived" subdirectory.
	[ -d $OPDIR/$KNAME/archived ] || mkdir -p $OPDIR/$KNAME/archived
	mv -f $OPDIR/$KNAME/$KNAME*.zip $OPDIR/$KNAME/archived/ &>/dev/null

	# Move the recently created flashable kernel into voided directory,
	mv $FSTMP/${KNAME}-$DATE.zip $OPDIR/$KNAME/ && rm -rf $FSTMP

	# Ensure all the above has been made successfully
	[ -s $OPDIR/$KNAME/${KNAME}-$DATE.zip ] &&
	print "${GRNCL}- ${KNAME}-$DATE.zip was successfully created!" ||
	terminate "5"
}

make_kernel()
{
	# This function expects configuration to be loaded.
	(config_loaded) || terminate "3" "Bake configuration"

	# Get current time in Seconds-Nanoseconds format.
	STIME=$(date +"%s.%N")

	# Compile the kernel and turn it into a flashable archive.
	__make_kernel
	__make_flashable

	# Clean-up the tree after the process
	prepare_kernel_tree

	# Get current time in Seconds-Nanosecods format again.
	ETIME=$(date +"%s.%N")
	# Now the difference between two times actually represents the elapsed
	# time for compilation, creating of a flashable and the clean-up.  We
	# can use bc to calculate the elapsed time properly.
	RTIME=$(echo "scale=1; ($ETIME - $STIME) / 1" | bc)

	print "${MGTCL}- Kernel was successfully built!"
	print "${CYACL}- Elapsed time: $RTIME seconds"
}

print "${CYACL}- Starting Bake v${BFVER}..."

# Ensure all the critical directories are created and non-empty.
for DIR in $CFDIR $KNDIR $FSDIR $TCDIR $OPDIR; do
	[ -s $DIR ] || terminate "0" "$DIR"
done

# Initialize the script immediately if it was not called in a bash context.
if [ ! "$0" == "bash" ]; then
	[ ! -z $1 ] || terminate "1"

	load_config $1
	make_kernel
fi
