#!/bin/sh
# udev dynamic firmware loading script
########################################################################

FIRMWARE_DIRS="/lib/firmware /lib/firmware/postmarketos"

exec >>/root/firmwareload.log 2>&1

if [ ! -e /sys/$DEVPATH/loading ]; then
    echo "firmware loader misses sysfs directory"
    exit 0
fi

for DIR in $FIRMWARE_DIRS; do
    [ -e "$DIR/$FIRMWARE" ] || continue
    echo "loading $DIR/$FIRMWARE"
    echo 1 > /sys/$DEVPATH/loading
    cat "$DIR/$FIRMWARE" > /sys/$DEVPATH/data
    echo 0 > /sys/$DEVPATH/loading
    exit
done

echo -1 > /sys/$DEVPATH/loading
echo "Cannot find  firmware file '$FIRMWARE'"
exit 1
