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

BFVER=3.1.0

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
NRCPS=$(($(grep "processor" /proc/cpuinfo | wc -l) * 2 ))

AUTAG="true"
TAGNM="breakfast"

print()
{
	printf "$1${RSTCL}\n"
	sleep 0.125
}

terminate()
{
	case "$1" in
		0) error="Bake is damaged!\n- Broken part -> $2";;
		1) error="No argument passed!";;
		2) error="$2 was not found!";;
		3) error="$2 was not loaded!";;
		4) error="Kernel stuck in build!";;
		5) error="Couldn't create flashable archive!";;
		6) error="I/O failure!";;
		*) error="Unknown error!";;
	esac

	print "${REDCL}- ERROR: $error\n\nScript terminated with error $1!" &&
	sleep 2.875

	exit $1
}

prepare_environment()
{
	for var in ARCH SUBARCH KNAME KTYPE DFCFG TOOLC; do unset $var; done
}

config_is_loaded()
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

	print "${MGTCL}- Loading $CRCFG..."
	prepare_environment

	source ${CFDIR}/$CRCFG &&
	export CROSS_COMPILE="$TCDIR/$TOOLC/bin/${TOOLC}-"
	(config_is_loaded) || terminate "3" "$CRCFG"

	print "${GRNCL}- $CRCFG was successfully loaded!"
}

prepare_kernel_tree()
{
	(config_is_loaded) || terminate "3" "Bake config"

	[ -f $KNDIR/$KNAME/Makefile ] && cd $KNDIR/$KNAME ||
	terminate "2" "$KNDIR/$KNAME/Makefile"

	print "${CYACL}- Preparing ${KNAME}..."

	[ -f scripts/basic/fixdep ] && (make clean; make mrproper)

	rm -rf arch/$ARCH/boot/*.dtb		\
	       arch/$ARCH/boot/*.cmd		\
	       arch/$ARCH/crypto/aesbs-core.S	\
	       arch/*/include/generated		\
	       include/generated

	find . -type f \( -iname \*.rej			\
		       -o -iname \*.orig		\
		       -o -iname \*.bkp			\
		       -o -iname \*.ko			\
		       -o -iname \*.c.BACKUP.[0-9]*.c	\
		       -o -iname \*.c.BASE.[0-9]*.c	\
		       -o -iname \*.c.LOCAL.[0-9]*.c	\
		       -o -iname \*.c.REMOTE.[0-9]*.c	\
		       -o -iname \*.org \)		\
				| parallel rm -fv {}

	[ "$CRCFG" == "hammerhead.conf" ] &&
	rm -f arch/$ARCH/mach-msm/smd_rpc_sym.c

	cd $CRDIR
}

sign_flashable()
{
	(config_is_loaded) || terminate "3" "Bake config"
	[ ! -z $1 ] || terminate "1"

	[ -f $SADIR/signapk.jar ] && [ -f $SADIR/keys/*.pk8 ] &&
	[ -f $SADIR/keys/*.pem ] && [ -f $FSDIR/$KNAME/$1 ] || return 1

	print "${CYACL}- Signing $1..."

	PVKEY=$(find $SADIR/keys/*.pk8 | head -1)
	PBKEY=$(find $SADIR/keys/*.pem | head -1)

	java -jar $SADIR/signapk.jar $PBKEY $PVKEY $FSDIR/$KNAME/$1 $SADIR/$1
	mv -f $SADIR/$1 $FSDIR/$KNAME/$1
}

make_flashable()
{
	(config_is_loaded) || terminate "3" "Bake config"

	[ -f $KNDIR/$KNAME/arch/$ARCH/boot/$KTYPE ] ||
	terminate "2" "$KNDIR/$KNAME/arch/$ARCH/boot/$KTYPE"

	print "${CYACL}- Creating flashable archive..."

	[ -d $FSDIR/$KNAME ] || mkdir -p $FSDIR/$KNAME/kernel
	mv -f $KNDIR/$KNAME/arch/$ARCH/boot/$KTYPE $FSDIR/$KNAME/kernel/

	DATE=$(date +"%Y%m%d")
	cd $FSDIR/$KNAME && zip -r ${KNAME}-$DATE.zip . && cd $CRDIR
	[ $? == "0" ] || terminate "6"

	sign_flashable "${KNAME}-$DATE.zip"

	[ -d $OPDIR/$KNAME/archived ] || mkdir -p $OPDIR/$KNAME/archived
	mv -f $OPDIR/$KNAME/$KNAME*.zip $OPDIR/$KNAME/archived/ &>/dev/null

	mv $FSDIR/$KNAME/${KNAME}-$DATE.zip $OPDIR/$KNAME/
	[ -f $OPDIR/$KNAME/${KNAME}-$DATE.zip ] || terminate "5"
}

make_kernel()
{
	(config_is_loaded) || terminate "3" "Bake config"

	[ -d $KNDIR/$KNAME ] && cd $KNDIR/$KNAME ||
	terminate "0" "$KNDIR/$KNAME"

	print "${CYACL}- Building ${KNAME}..."
	for i in 3 2 1; do
		print "${BLUCL}- Build starts in $i"
		sleep 0.875
	done

	STIME=$(date +"%s.%N")
	[ $AUTAG == "true" ] && git tag -afm "$TAGNM" $TAGNM &>/dev/null

	make $DFCFG
	make -j$NRCPS $KTYPE				\
		REAL_CC="$CACHE ${CROSS_COMPILE}gcc"	\
		CFLAGS_MODULE="-DMODULE $FLAGS"		\
		AFLAGS_MODULE="-DMODULE $FLAGS"		\
		CFLAGS_KERNEL="$FLAGS"			\
		AFLAGS_KERNEL="$FLAGS"
	cd $CRDIR

	[ -f $KNDIR/$KNAME/arch/$ARCH/boot/$KTYPE ] &&
	(make_flashable; prepare_kernel_tree) || terminate "4"

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
	prepare_kernel_tree
	make_kernel
fi
