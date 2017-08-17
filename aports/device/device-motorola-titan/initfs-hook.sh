#!/bin/sh

# set framebuffer resolution
cat /sys/class/graphics/fb0/modes > /sys/class/graphics/fb0/mode

# set usb properties
echo -n "Motorola"    > /sys/devices/virtual/android_usb/android0/iManufacturer
echo -n "Moto G 2014" > /sys/devices/virtual/android_usb/android0/iProduct
echo -n "ZX1D229ZG4"  > /sys/devices/virtual/android_usb/android0/iSerial
