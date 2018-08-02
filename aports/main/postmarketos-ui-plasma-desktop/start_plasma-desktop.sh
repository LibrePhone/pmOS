if test -z "${XDG_RUNTIME_DIR}"; then
	export XDG_RUNTIME_DIR=/run/user/$(id -u)

	if [ $(tty) = "/dev/tty1" ]; then
		udevadm trigger
		udevadm settle
	
		export QML2_IMPORT_PATH=/usr/lib/qt/qml:/usr/lib/qt5/qml

		sleep 2

		ck-launch-session dbus-run-session startplasmacompositor 2>&1 | logger -t "$(whoami):plasma-desktop"
	fi
fi
