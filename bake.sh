#!/bin/bash
clear

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

BFVER=3.1.1

REDCL=$(tput bold)$(tput setaf 1)
GRNCL=$(tput bold)$(tput setaf 2)
BLUCL=$(tput bold)$(tput setaf 4)
MGTCL=$(tput bold)$(tput setaf 5)
CYACL=$(tput bold)$(tput setaf 6)
RSTCL=$(tput sgr0)

CRDIR=$(pwd)
RTDIR=$(cd $(dirname ${BASH_SOURCE[0]}) && pwd)
CFDIR="${RTDIR}/configs"
KNDIR="${RTDIR}/kernels"
SADIR="${RTDIR}/signapk"
FSDIR="${RTDIR}/flashables"
TCDIR="${RTDIR}/toolchains"
OPDIR="${RTDIR}/outputs"
NRCPS=$[ $(grep "processor" /proc/cpuinfo | wc -l) * 2 ]

AUTAG="true"
TAGNM="breakfast"

print() { printf "$1${RSTCL}\n"; sleep 0.125; }

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

	print "${REDCL}- ERROR: $error\n\nScript terminated with error $1!" &&
	sleep 2.875

	exit $1
}

prepare_environment()
{
	print "${CYACL}- Preparing working environment..."
	for var in ARCH SUBARCH KNAME KTYPE DFCFG TOOLC; do unset $var; done
}

config_loaded()
{
	[ ! -z $ARCH ] && [ ! -z $SUBARCH ] && [ ! -z $KNAME ] &&
	[ ! -z $KTYPE ] && [ ! -z $DFCFG ] && [ ! -z $TOOLC ] &&
	[ ! -z $CROSS_COMPILE ] || return 1

	return 0
}

load_config()
{
	[ ! -z $1 ] || terminate "1"

	CRCFG=$(find $CFDIR/$1* -printf "%f\n" -quit 2>/dev/null)
	[ ! -z $CRCFG ] || terminate "2" "$1"

	print "${MGTCL}- Loading new Bake configuration --> $CRCFG..."
	prepare_environment

	source ${CFDIR}/$CRCFG &&
	export CROSS_COMPILE="$TCDIR/$TOOLC/bin/${TOOLC}-"

	print "${MGTCL}- Validating Bake configuration..."
	(config_loaded) || terminate "3" "$CRCFG"

	print "${GRNCL}- $CRCFG was successfully loaded!"
}

prepare_kernel_tree()
{
	(config_loaded) || terminate "3" "Bake configuration"

	[ -f $KNDIR/$KNAME/Makefile ] && cd $KNDIR/$KNAME ||
	terminate "2" "$KNDIR/$KNAME/Makefile"

	print "${CYACL}- Preparing ${KNAME} tree..."

	[ -f scripts/basic/fixdep ] && (make clean; make mrproper)

	rm -rf arch/$ARCH/boot/*.dtb		\
	       arch/$ARCH/boot/*.cmd		\
	       arch/$ARCH/crypto/aesbs-core.S	\
	       arch/*/include/generated		\
	       include/generated

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

	[ "$CRCFG" == "hammerhead.conf" ] &&
	rm -f arch/$ARCH/mach-msm/smd_rpc_sym.c

	cd $CRDIR
}

sign_flashable()
{
	(config_loaded) || terminate "3" "Bake configuration"
	[ ! -z $1 ] || terminate "1"

	[ -f $SADIR/signapk.jar ] && [ -f $SADIR/keys/*.pk8 ] &&
	[ -f $SADIR/keys/*.pem ] && [ -f $FSDIR/$KNAME/$1 ] || return 1

	print "${CYACL}- Signing $1 archive..."

	PVKEY=$(find $SADIR/keys/*.pk8 | head -1)
	PBKEY=$(find $SADIR/keys/*.pem | head -1)

	java -jar $SADIR/signapk.jar $PBKEY $PVKEY $FSDIR/$KNAME/$1 $SADIR/$1
	mv -f $SADIR/$1 $FSDIR/$KNAME/$1

	print "${GRNCL}- $1 was successfully signed!"
}

__make_kernel()
{
	(config_loaded) || terminate "3" "Bake configuration"

	prepare_kernel_tree

	[ -f $KNDIR/$KNAME/Makefile ] && cd $KNDIR/$KNAME ||
	terminate "2" "$KNDIR/$KNAME/Makefile"

	[ -f $KNDIR/$KNAME/.git ] && BRANC=$(git rev-parse --abbrev-ref HEAD) ||
	BRANC="unstated"

	print "${CYACL}- Building ${KNAME} (\"$BRANC\" branch)..."
	for ((i = 3; i > 0; i--)); do
		print "${BLUCL}- Build starts in $i"; sleep 0.875
	done

	[ $AUTAG == "true" ] && git tag -afm "$TAGNM" $TAGNM &>/dev/null

	make $DFCFG && make -j$NRCPS $KTYPE REAL_CC="$CACHE ${CROSS_COMPILE}gcc"

	[ -f $KNDIR/$KNAME/arch/$ARCH/boot/$KTYPE ] &&
	print "${GRNCL}- ${KNAME} was successfully built!" || terminate "4"

	cd $CRDIR
}

__move_kernel_to_flashable()
{
	(config_loaded) || terminate "3" "Bake configuration"
	[ ! -z $1 ] || terminate "1"

	[ -f $KNDIR/$KNAME/arch/$ARCH/boot/$KTYPE ] ||
	terminate "2" "$KNDIR/$KNAME/arch/$ARCH/boot/$KTYPE"

	[ -d $FSDIR/$KNAME/kernel ] || mkdir -p $FSDIR/$KNAME/kernel

	print "${CYACL}- Moving $KTYPE to $FSDIR/$KNAME/kernel/$1"
	mv -f $KNDIR/$KNAME/arch/$ARCH/boot/$KTYPE $FSDIR/$KNAME/kernel/$1
}

make_another_branch()
{
	(config_loaded) || terminate "3" "Bake configuration"
	[ ! -z $1 ] || return 1

	[ -d $KNDIR/$KNAME/.git ] && cd $KNDIR/$KNAME ||
	terminate "2" "$KNDIR/$KNAME/.git"

	CURBR=$(git rev-parse --abbrev-ref HEAD)

	print "${MGTCL}- Switching to \"$1\" branch..."
	git checkout $1 &>/dev/null
	[ "$?" -eq "0" ] || return 1

	print "${MGTCL}- Building \"$1\" branch..."

	__make_kernel
	__move_kernel_to_flashable "${KTYPE}_o"

	[ -d $KNDIR/$KNAME/.git ] && cd $KNDIR/$KNAME ||
	terminate "2" "$KNDIR/$KNAME/.git"

	git checkout $CURBR &>/dev/null
	print "${CYACL}- Going back to \"$CURBR\" branch..."
}

make_flashable()
{
	(config_loaded) || terminate "3" "Bake configuration"

	print "${CYACL}- Creating flashable archive..."

	DATE=$(date +"%Y%m%d")
	[ -d $FSDIR/$KNAME/kernel ] || mkdir -p $FSDIR/$KNAME/kernel
	[ ! -z $1 ] || rm -f $FSDIR/$KNAME/kernel/${KTYPE}_*

	cd $FSDIR/$KNAME && zip -r ${KNAME}-$DATE.zip . && cd $CRDIR
	[ "$?" -eq "0" ] || terminate "6"

	sign_flashable "${KNAME}-$DATE.zip"

	[ -d $OPDIR/$KNAME/archived ] || mkdir -p $OPDIR/$KNAME/archived
	mv -f $OPDIR/$KNAME/$KNAME*.zip $OPDIR/$KNAME/archived/ &>/dev/null

	mv $FSDIR/$KNAME/${KNAME}-$DATE.zip $OPDIR/$KNAME/
	[ -f $OPDIR/$KNAME/${KNAME}-$DATE.zip ] &&
	print "${GRNCL}- ${KNAME}-$DATE.zip was successfully created!" ||
	terminate "5"
}

make_kernel()
{
	(config_loaded) || terminate "3" "Bake configuration"

	STIME=$(date +"%s.%N")

	__make_kernel
	__move_kernel_to_flashable $KTYPE

	make_another_branch $1
	make_flashable $1

	prepare_kernel_tree

	ETIME=$(date +"%s.%N")
	RTIME=$(echo "scale=1; ($ETIME - $STIME) / 1" | bc)

	print "${MGTCL}- Kernel was successfully built!"
	print "${CYACL}- Elapsed time: $RTIME seconds"
}

print "${CYACL}- Starting Bake v${BFVER}..."

for DIR in $CFDIR $KNDIR $FSDIR $TCDIR $OPDIR; do
	[ -s $DIR ] || terminate "0" "$DIR"
done

if [ ! "$0" == "bash" ]; then
	[ ! -z $1 ] || terminate "1"

	load_config $1
	make_kernel $2
fi
