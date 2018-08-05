if test -z "${XDG_RUNTIME_DIR}"; then
	export XDG_RUNTIME_DIR=/run/user/$(id -u)
	if ! test -d "${XDG_RUNTIME_DIR}"; then
		mkdir "${XDG_RUNTIME_DIR}"
		chmod 0700 "${XDG_RUNTIME_DIR}"
	fi

	if [ $(tty) = "/dev/tty1" ]; then
		udevadm trigger
		udevadm settle

		sleep 2

		/usr/bin/rootston -C /etc/rootston.ini phosh 2>&1 | logger -t "$(whoami):phosh"
	fi
fi
