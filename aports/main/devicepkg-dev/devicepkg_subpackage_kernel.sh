#!/bin/sh
startdir=$1
pkgname=$2
subpkgname=$3

if [ -z "$startdir" ] || [ -z "$pkgname" ] || [ -z "$subpkgname" ]; then
	echo "ERROR: missing argument!"
	echo "Please call $0 with \$startdir \$pkgname \$subpkgname as arguments."
	exit 1
fi

srcdir="$startdir/src"
pkgdir="$startdir/pkg/$pkgname"
subpkgdir="$startdir/pkg/$subpkgname"

if [ -e "$pkgdir/etc/deviceinfo" ]; then
	rm -v "$pkgdir/etc/deviceinfo"
fi

kernel=$(echo $subpkgname | sed -n "s/.*-kernel-\(.*\)/\1/p")

sed "s/deviceinfo_kernel_cmdline_$kernel/deviceinfo_kernel_cmdline/g" "$srcdir/deviceinfo" | \
  sed ":a;N;s/deviceinfo_kernel_cmdline_.*\n//g;ba" > "$srcdir/deviceinfo_$kernel"
install -Dm644 "$srcdir/deviceinfo_$kernel" \
  "$subpkgdir/etc/deviceinfo"
