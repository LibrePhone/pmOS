#!/bin/sh

source_deviceinfo()
{
	if [ ! -e "/etc/deviceinfo" ]; then
		echo "NOTE: deviceinfo (from device package) not installed yet," \
			"not building the initramfs now (it should get built later" \
			"automatically.)"
		exit 0
	fi
	. /etc/deviceinfo
}

parse_commandline()
{
	if [ "$1" != "-o" ]; then
		echo "postmarketos-mkinitfs"
		echo "usage: $(basename "$0") -o OUTFILE KERNELVERSION"
		exit 1
	fi

	outfile=$2
	outfile_extra=$2-extra
	kernel=$3
	modules_path="/lib/modules/${kernel}"
}

# Verify that each file required by the installed hooks exists and exit with an
# error if they don't.
check_hook_files()
{
	for file in "/etc/postmarketos-mkinitfs/files"/*.files; do
		[ -f "$file" ] || continue
		while IFS= read -r line; do
			if ! [ -f "$line" ]; then
				echo "ERROR: File ${line} specified in ${file} does not exist!"
				exit 1
			fi
		done < "$file"
	done
}

create_folders()
{
	for dir in /bin /sbin /usr/bin /usr/sbin /proc /sys /dev /tmp /lib \
		/boot /sysroot /etc; do
		mkdir -p "$tmpdir$dir"
	done
}

get_modules_by_globs()
{
	globs="
		# base.modules
		kernel/drivers/block/loop.ko
		kernel/fs/overlayfs

		# cryptsetup.modules
		kernel/crypto/*
		kernel/arch/*/crypto/*
		kernel/drivers/md/dm-crypt.ko

		# required for modprobe
		modules.*
	"

	for glob in $globs; do
		for file in /lib/modules/$kernel/$glob; do
			if [ -d "$file" ]; then
				find "$file" -type f
			elif [ -e "$file" ]; then
				echo "$file"
			fi
		done
	done
}

# NOTE: This does not work with busybox' modprobe
# That's why postmarketos-mkinitfs depends on kmod
get_modules_by_name()
{
	{
		echo "Scanning kernel module dependencies..."
		echo "NOTE: ** modprobe warnings below can be ignored ** if your device does not run the"
		echo "mainline kernel yet (most devices!) or if the related kernel options are enabled"
		echo "with 'y' instead of 'm' (module)."
	} >&2

	MODULES="drm_kms_helper drm dm_crypt \
		${deviceinfo_modules_initfs}"
	modprobe \
		-a \
		--dry-run \
		--show-depends \
		--set-version="$kernel" \
		$MODULES \
		| sort -u \
		| cut -d ' ' -f 2
}

get_modules()
{
	get_modules_by_globs
	get_modules_by_name
}

# Get the paths to all binaries and their dependencies
BINARIES="/bin/busybox /bin/busybox-extras /usr/sbin/telnetd /sbin/kpartx"
BINARIES_EXTRA="
	$(find /usr/lib/directfb-* -name '*.so')
	/lib/libz.so.1
	/sbin/cryptsetup
	/sbin/dmsetup
	/sbin/e2fsck
	/usr/bin/charging-sdl
	/usr/bin/osk-sdl
	/usr/lib/libGL.so.1
	/usr/lib/libts*
	/usr/lib/ts/*
	/usr/sbin/parted
	/usr/sbin/resize2fs
	/usr/sbin/thd
"
get_binaries()
{
	for file in "/etc/postmarketos-mkinitfs/files"/*.files; do
		[ -f "$file" ] || continue
		while IFS= read -r line; do
			BINARIES="${BINARIES} ${line}"
		done < "$file"
	done
	lddtree -l $BINARIES | sort -u
}

# Collect non-binary files for osk-sdl and its dependencies
# This gets called as $(get_osk_config), so the exit code can be checked/handled.
get_osk_config()
{
	fontpath=$(awk '/^keyboard-font/{print $3}' /etc/osk.conf)
	if [ ! -f $fontpath ]; then
		exit 1
	fi
	ret="
		/etc/osk.conf
		/etc/ts.conf
		/etc/pointercal
		/etc/fb.modes
		$fontpath
	"
	echo "${ret}"
}

get_binaries_extra()
{
	tmp1=$(mktemp /tmp/mkinitfs.XXXXXX)
	get_binaries > "$tmp1"
	tmp2=$(mktemp /tmp/mkinitfs.XXXXXX)
	lddtree -l $BINARIES_EXTRA | sort -u > "$tmp2"
	ret=$(comm -13 "$tmp1" "$tmp2")
	rm "$tmp1" "$tmp2"
	echo "${ret}"
}

# Copy files to the destination specified
# FIXME: this is a performance bottleneck
# $1: files
# $2: destination
copy_files()
{
	for file in $1; do
		[ -e "$file" ] || continue
		cp -a --parents "$file" "$2"
	done
}

create_device_nodes()
{
	mknod -m 666 "$tmpdir/dev/null" c 1 3
	mknod -m 644 "$tmpdir/dev/random" c 1 8
	mknod -m 644 "$tmpdir/dev/urandom" c 1 9
}

replace_init_variables()
{
	sed -i "s:@INITRAMFS_EXTRA@:${outfile_extra}:g" "$tmpdir/init"
}

# Create a cpio image of the specified folder
# $1: folder
# $2: outfile
create_cpio_image()
{
	cd "$1"
	find . -print0 \
		| cpio --quiet -o -H newc \
		| gzip -1 > "$2"
}

# Required command check with useful error message
# $1: command (e.g. "mkimage")
# $2: package (e.g. "uboot-tools")
# $3: related deviceinfo variable (e.g. "generate_bootimg")
require_package()
{
	[ "$(command -v "$1")" == "" ] || return
	echo "ERROR: 'deviceinfo_$3' is set, but the package '$2' was not"
	echo "installed! Please add '$2' to the depends= line of your device's"
	echo "APKBUILD. See also: <https://postmarketos.org/deviceinfo>"
	exit 1
}

# Legacy u-boot images
create_uboot_files()
{
	[ "${deviceinfo_generate_legacy_uboot_initfs}" == "true" ] || return
	require_package "mkimage" "uboot-tools" "generate_legacy_uboot_initfs"

	echo "==> initramfs: creating uInitrd"
	mkimage -A arm -T ramdisk -C none -n uInitrd -d "$outfile" \
		"${outfile/initramfs-/uInitrd-}" || exit 1

	echo "==> kernel: creating uImage"
	kernelfile="${outfile/initramfs-/vmlinuz-}"
	if [ -n "${deviceinfo_dtb}" ]; then
		kernelfile="${kernelfile}-dtb"
	fi
	mkimage -A arm -O linux -T kernel -C none -a 80008000 -e 80008000 \
		-n postmarketos -d $kernelfile "${outfile/initramfs-/uImage-}" || exit 1
}

# Android devices
create_bootimg()
{
	[ "${deviceinfo_generate_bootimg}" == "true" ] || return
	require_package "mkbootimg-osm0sis" "mkbootimg" "generate_bootimg"

	echo "==> initramfs: creating boot.img"
	_base="${deviceinfo_flash_offset_base}"
	[ -z "$_base" ] && _base="0x10000000"

	kernelfile="${outfile/initramfs-/vmlinuz-}"
	if [ -n "${deviceinfo_dtb}" ]; then
		kernelfile="${kernelfile}-dtb"
	fi
	_dt=""
	if [ "${deviceinfo_bootimg_qcdt}" == "true" ]; then
		_dt="--dt /boot/dt.img"
		if ! [ -e "/boot/dt.img" ]; then
			echo "ERROR: File not found: /boot/dt.img, but"
			echo "'deviceinfo_bootimg_qcdt' is set. Please verify that your"
			echo "device is a QCDT device by analyzing the boot.img file"
			echo "(e.g. 'pmbootstrap bootimg_analyze path/to/twrp.img')"
			echo "and based on that, set the deviceinfo variable to false or"
			echo "adjust your linux APKBUILD to properly generate the dt.img"
			echo "file. See also: <https://postmarketos.org/deviceinfo>"
			exit 1
		fi
	fi
	mkbootimg-osm0sis \
		--kernel "${kernelfile}" \
		--ramdisk "$outfile" \
		--base "${_base}" \
		--second_offset "${deviceinfo_flash_offset_second}" \
		--cmdline "${deviceinfo_kernel_cmdline}" \
		--kernel_offset "${deviceinfo_flash_offset_kernel}" \
		--ramdisk_offset "${deviceinfo_flash_offset_ramdisk}" \
		--tags_offset "${deviceinfo_flash_offset_tags}" \
		--pagesize "${deviceinfo_flash_pagesize}" \
		${_dt} \
		-o "${outfile/initramfs-/boot.img-}" || exit 1
	if [ "${deviceinfo_bootimg_blobpack}" == "true" ]; then
		echo "==> initramfs: creating blob"
		blobpack "${outfile/initramfs-/blob-}" LNX \
			"${outfile/initramfs-/boot.img-}" || exit 1
	fi
}

# Create splash screens
# $1: "false" to skip clearing the cache if one image is missing
generate_splash_screens()
{
	[ "$1" != "false" ] && clean="true" || clean="false"

	splash_version=$(apk info -v | grep postmarketos-splash)
	if [ -z "$splash_version" ]; then
		# If package is not installed yet, use latest version from repository
		splash_version=$(apk search -x postmarketos-splash)
	fi
	splash_config="/etc/postmarketos/splash.ini"
	splash_config_hash=$(md5sum "$splash_config")
	splash_width=${deviceinfo_screen_width:-720}
	splash_height=${deviceinfo_screen_height:-1280}
	splash_cache_dir="/var/cache/postmarketos-splashes"

	# Overwrite $@ to easily iterate over the splash screens. Format:
	# $1: splash_name
	# $2: text
	# $3: arguments
	set -- "splash-loading"          "Loading..." "--center" \
	       "splash-noboot"           "boot partition not found\\nhttps://postmarketos.org/troubleshooting" "--center" \
	       "splash-noinitramfsextra" "initramfs-extra not found\\nhttps://postmarketos.org/troubleshooting" "--center" \
	       "splash-norootfs"         "rootfs not found\\nhttps://postmarketos.org/troubleshooting" "--center" \
	       "splash-mounterror"       "unable to mount root partition\\nhttps://postmarketos.org/troubleshooting" "--center" \
	       "splash-debug-shell"      "WARNING\\ndebug-shell is active\\nhttps://postmarketos.org/debug-shell" "--center"

	# Ensure cache folder exists
	mkdir -p "${splash_cache_dir}"

	# Loop through the splash screens definitions
	while [ $# -gt 2 ]
	do
		splash_name=$1
		splash_text=$2
		splash_args=$3

		# Compute hash using the following values concatenated:
		# - postmarketos-splash package version
		# - splash config file
		# - device resolution
		# - text to be displayed
		splash_hash_string="${splash_version}#${splash_config_hash}#${splash_width}#${splash_height}#${splash_text}"
		splash_hash="$(echo "${splash_hash_string}" | md5sum | awk '{ print $1 }')"

		if ! [ -e "${splash_cache_dir}/${splash_name}_${splash_hash}.ppm.gz" ]; then

			# If a cached file is missing, clear the whole cache and start again skipping this step
			if [ "$clean" = "true" ]; then
				rm -f ${splash_cache_dir}/*
				generate_splash_screens false
				return
			fi

			# shellcheck disable=SC2086
			pmos-make-splash --text="${splash_text}" $splash_args --config "${splash_config}" \
					"$splash_width" "$splash_height" "${splash_cache_dir}/${splash_name}_${splash_hash}.ppm"
			gzip "${splash_cache_dir}/${splash_name}_${splash_hash}.ppm"
		fi

		cp "${splash_cache_dir}/${splash_name}_${splash_hash}.ppm.gz" "${tmpdir}/${splash_name}.ppm.gz"

		shift 3 # move to the next 3 arguments
	done
}

# Append the correct device tree to the linux image file
append_device_tree()
{
	[ -n "${deviceinfo_dtb}" ] || return
	dtb="/usr/share/dtb/${deviceinfo_dtb}.dtb"
	kernel="${outfile/initramfs-/vmlinuz-}"
	echo "==> kernel: appending device-tree ${deviceinfo_dtb}"
	if [ -e "$dtb" ]; then
		cat "$kernel" "$dtb" > "${kernel}-dtb"
	else
		echo "NOTE: device tree does not exist, not appending it to the kernel."
		echo "This is expected for downstream kernels."
		cp "$kernel" "${kernel}-dtb"
	fi
}

# Create the initramfs-extra archive
# $1: outfile
generate_initramfs_extra()
{
	echo "==> initramfs: creating $1"

	osk_conf="$(get_osk_config)"
	if [ $? -eq 1 ]; then
		echo "ERROR: Font specified in /etc/osk.conf does not exist!"
		exit 1
	fi

	# Ensure cache folder exists
	mkinitfs_cache_dir="/var/cache/postmarketos-mkinitfs"
	mkdir -p "$mkinitfs_cache_dir"

	# Generate cache output filename (initfs_extra_cache) by hashing all input files
	initfs_extra_files=$(echo "$BINARIES_EXTRA$osk_conf" | xargs -0 -I{} sh -c 'ls $1 2>/dev/null' -- {} | sort -u)
	initfs_extra_files_hashes="$(md5sum $initfs_extra_files)"
	initfs_extra_hash="$(echo "$initfs_extra_files_hashes" | md5sum | awk '{ print $1 }')"
	initfs_extra_cache="$mkinitfs_cache_dir/$(basename $1)_${initfs_extra_hash}"

	if ! [ -e "$initfs_extra_cache" ]; then
		# If a cached file is missing, clear the whole cache and create it
		rm -f ${mkinitfs_cache_dir}/*

		# Set up initramfs-extra in temp folder
		tmpdir_extra=$(mktemp -d /tmp/mkinitfs.XXXXXX)
		mkdir -p "$tmpdir_extra"
		copy_files "$(get_binaries_extra)" "$tmpdir_extra"
		copy_files "$osk_conf" "$tmpdir_extra"
		create_cpio_image "$tmpdir_extra" "$initfs_extra_cache"
		rm -rf "$tmpdir_extra"
	fi

	cp "$initfs_extra_cache" "$1"
}

# initialize
source_deviceinfo
parse_commandline "$1" "$2" "$3"
check_hook_files
echo "==> initramfs: creating $outfile"
tmpdir=$(mktemp -d /tmp/mkinitfs.XXXXXX)

# set up initfs in temp folder
create_folders
copy_files "$(get_modules)" "$tmpdir"
copy_files "$(get_binaries)" "$tmpdir"
copy_files "/etc/deviceinfo" "$tmpdir"
copy_files "/etc/postmarketos-mkinitfs/hooks/*.sh" "$tmpdir"
create_device_nodes
ln -s "/bin/busybox" "$tmpdir/bin/sh"
install -Dm755 "/usr/share/postmarketos-mkinitfs/init.sh.in" \
	"$tmpdir/init"
install -Dm755 "/usr/share/postmarketos-mkinitfs/init_functions.sh" \
	"$tmpdir/init_functions.sh"

# finish up
generate_splash_screens
replace_init_variables
create_cpio_image "$tmpdir" "$outfile"
append_device_tree
create_uboot_files
create_bootimg

rm -rf "$tmpdir"

generate_initramfs_extra "$outfile_extra"

exit 0
