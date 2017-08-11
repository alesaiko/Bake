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

bf_ver=3.0.0

clr_red=$(tput bold)$(tput setaf 1);
clr_green=$(tput bold)$(tput setaf 2);
clr_yellow=$(tput bold)$(tput setaf 3);
clr_blue=$(tput bold)$(tput setaf 4);
clr_magenta=$(tput bold)$(tput setaf 5);
clr_cyan=$(tput bold)$(tput setaf 6);
clr_reset=$(tput sgr0);

root_dir=$(readlink -f .);
configs_dir="${root_dir}/configs"
kernels_dir="${root_dir}/kernels"
signapk_dir="${root_dir}/signapk"
flashables_dir="${root_dir}/flashables"
toolchains_dir="${root_dir}/toolchains"
outputs_dir="${root_dir}/outputs"

let "nr_cpus = $(grep "processor" /proc/cpuinfo | wc -l) * 2"

print()
{
	# Delay is required to make output smoother
	printf "$1\n"; sleep 0.125
}

terminate()
{
	[ "$1" == "-1" ] && error="Bake is damaged!\n----- Broken part -> $2"
	[ "$1" == "0" ] && error="No argument passed!"
	[ "$1" == "1" ] && error="$2 was not found!"
	[ "$1" == "2" ] && error="$2 was not loaded!"
	[ "$1" == "3" ] && error="Kernel stuck in build!"
	[ "$1" == "4" ] && error="Could not create flashable archive!"

	print "${clr_red}----- ERROR: $error\n\nScript terminated with error $1${clr_reset}"
	[ $3 ] && sleep $3 || sleep 3
	exit $1
}

check_bake_init()
{
	print "${clr_cyan}----- Starting Bake v${bf_ver}...${clr_reset}"

	for dir in $configs_dir $kernels_dir $flashables_dir \
		   $toolchains_dir $outputs_dir; do
		[ -s $dir ] || terminate "-1" "$dir"
	done
}; check_bake_init

find_config()
{
	export cur_config=$(find $configs_dir/$1* -printf "%f\n" -quit 2>/dev/null);
	[ $cur_config ] || terminate "1" "$1"
}

check_args()
{
	[ "$1" == "config" ] &&
	if [ ! $ARCH ] || [ ! $SUBARCH ] || [ ! $flashable_name ] ||
	   [ ! $kernel_name ] || [ ! $kernel_image ] || [ ! $defconfig ] ||
	   [ ! $toolchain ]; then
		return 0
	fi

	return 1
}

init_bake_config()
{
	print "${clr_magenta}----- Loading $1...${clr_reset}"

	source ${configs_dir}/$1
	if (check_args "config"); then terminate "2" "$1"; fi

	export CROSS_COMPILE="$toolchains_dir/$toolchain/bin/${toolchain}-"

	print "${clr_green}----- $1 was successfully loaded!${clr_reset}"
}

cleanup_kernel_tree()
{
	if [ -d $kernels_dir/$kernel_name ]; then
		print "${clr_cyan}----- Cleaning ${kernel_name}...${clr_reset}"

		cd $kernels_dir/$kernel_name

		[ -f scripts/basic/fixdep ] && (make clean; make mrproper);

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

		cd $root_dir
	else
		terminate "-1" "$kernels_dir/$kernel_name"
	fi
}

sign_flashable()
{
	[ -f $signapk_dir/signapk.jar ] &&
	[ -f $signapk_dir/keys/*.pk8 ] &&
	[ -f $signapk_dir/keys/*.pem ] &&
	[ -f $flashables_dir/$kernel_name/$1 ] ||
	return 0

	private_key=$(find $signapk_dir/keys/*.pk8 | head -1);
	public_key=$(find $signapk_dir/keys/*.pem | head -1);

	java -jar $signapk_dir/signapk.jar $public_key $private_key \
		  $flashables_dir/$kernel_name/$1 $signapk_dir/$1

	mv -f $signapk_dir/$1 $flashables_dir/$kernel_name/$1
}

make_flashable()
{
	print "${clr_cyan}----- Creating flashable archive...${clr_reset}"

	[ -f $kernels_dir/$kernel_name/arch/$ARCH/boot/$kernel_image ] ||
	terminate "-1" $kernels_dir/$kernel_name/arch/$ARCH/boot/$kernel_image

	cd $flashables_dir

	[ -d $kernel_name ] || mkdir -p $kernel_name/kernel

	rm -f $flashables_dir/$kernel_name/kernel/$kernel_image
	mv $kernels_dir/$kernel_name/arch/$ARCH/boot/$kernel_image $kernel_name/kernel

	date=$(date +"%Y%m%d");
	cd $kernel_name && zip -r ${kernel_name}-$date.zip . && cd $flashables_dir

	sign_flashable "${kernel_name}-$date.zip"

	[ -d $outputs_dir/$kernel_name/archived ] ||
	mkdir -p $outputs_dir/$kernel_name/archived
	[ -f $outputs_dir/$kernel_name/$kernel_name* ] &&
	mv $outputs_dir/$kernel_name/$kernel_name* $outputs_dir/$kernel_name/archived/

	mv $flashables_dir/$kernel_name/${kernel_name}-$date.zip $outputs_dir/$kernel_name/
	[ -f $outputs_dir/$kernel_name/${kernel_name}-$date.zip ] || terminate "4"

	cd $root_dir
}

make_kernel()
{
	if [ -d $kernels_dir/$kernel_name ]; then
		print "${clr_cyan}----- Building ${kernel_name}...${clr_reset}"
		print "${clr_blue}----- Build starts in 3${clr_reset}"; sleep 1
		print "${clr_blue}----- Build starts in 2${clr_reset}"; sleep 1
		print "${clr_blue}----- Build starts in 1${clr_reset}"; sleep 1

		start_time=$(date +"%s.%N");

		cd $kernels_dir/$kernel_name

		make $defconfig && make -j$nr_cpus $kernel_image

		[ -f arch/$ARCH/boot/$kernel_image ] &&
		(make_flashable; cleanup_kernel_tree) || terminate "3"

		cd $root_dir

		end_time=$(date +"%s.%N");
		elapsed_time=$(echo "scale=1; ($end_time - $start_time) / 1" | bc);

		print "${clr_magenta}----- Kernel was successfully built!${clr_reset}"
		print "${clr_cyan}----- Elapsed time: $elapsed_time seconds${clr_reset}"
	else
		terminate "-1" "$kernels_dir/$kernel_name"
	fi
}


[ "$0" == "bash" ] || ([ $1 ] || terminate "0" &&
(find_config $1
init_bake_config $cur_config
cleanup_kernel_tree
make_kernel));
