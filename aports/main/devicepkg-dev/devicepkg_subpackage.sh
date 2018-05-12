#!/bin/sh
startdir=$1
subpkgname=$2
kernel=$(echo $subpkgname | sed -n "s/.*-kernel-\(.*\)/\1/p")

if [ -z "$startdir" ] || [ -z "$subpkgname" ]; then
	echo "ERROR: missing argument!"
	echo "Please use $0 with \$startdir and \$subpkgname as arguments."
	exit 1
fi

srcdir="$startdir/src"
subpkgdir="$startdir/pkg/$subpkgname"

if [ ! -f "$srcdir/deviceinfo" ]; then
	echo "ERROR: deviceinfo file missing!"
	exit 1
fi

if grep -qE "^deviceinfo_kernel_cmdline=" "$srcdir/deviceinfo"; then
	echo "ERROR: deviceinfo contains a generic kernel cmdline variable!"
	exit 1
fi

if grep -q "deviceinfo_kernel_cmdline_$kernel" "$srcdir/deviceinfo"; then
	sed "s/deviceinfo_kernel_cmdline_$kernel/deviceinfo_kernel_cmdline/g" "$srcdir/deviceinfo" | \
		sed ":a;N;s/deviceinfo_kernel_cmdline_.*\n//g;ba" > "$srcdir/deviceinfo_$kernel"
	install -Dm644 "$srcdir/deviceinfo_$kernel" \
		"$subpkgdir/etc/deviceinfo"
else
	echo "ERROR: deviceinfo doesn't contain the \"deviceinfo_kernel_cmdline_$kernel\" variable!"
	exit 1
fi