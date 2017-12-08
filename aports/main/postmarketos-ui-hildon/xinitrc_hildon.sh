#!/bin/sh

# Set default wallpapers
mkdir -p ~/.backgrounds
for i in 1 2 3 4; do
	source=/usr/share/themes/alpha/backgrounds/wallpaper$i.png
	destination=~/.backgrounds/background-$i.png
	[ -e "$destination" ] || ln -s "$source" "$destination"
done

# Start dbus and export its environment variables
eval "$(dbus-launch --sh-syntax --exit-with-session)"

. /etc/deviceinfo
if [ ! -z "$deviceinfo_dev_touchscreen" ]; then
	# walk through all the attributes of the parent devices and reverse the
	# output to find and extract the name attribute of the top parent device
	touch_name=$(udevadm info -a -n "${deviceinfo_dev_touchscreen}" | tac | grep -m1 "ATTRS{name}" | cut -d '"' -f2)
	xinput set-prop "$touch_name" "Coordinate Transformation Matrix" 0 1 0 -1 0 1 0 0 1
fi

# Start X11 with Hildon
export LC_MESSAGES=en_US.UTF-8
exec hildon-desktop
