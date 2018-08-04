#!/usr/bin/env python3
"""
Copyright 2018 Oliver Smith

This file is part of pmbootstrap.

pmbootstrap is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

pmbootstrap is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with pmbootstrap.  If not, see <http://www.gnu.org/licenses/>.
"""
import argparse
import glob
import os
import sys
import urllib.request


def get_devices():
    """:returns: list of all devices in the aports folders"""
    ret = []
    pmb_src = os.path.realpath(os.path.join(os.path.dirname(__file__) + "/.."))
    for path in glob.glob(pmb_src + "/aports/device/device-*/"):
        device = os.path.dirname(path).split("device-", 1)[1]
        ret.append(device)
    return sorted(ret)


def get_wiki_devices_html(path):
    """:param path: to a local file with the saved content of the devices wiki
                    page or None to download a fresh copy
       :returns: HTML of the page, split into booting and not booting:
                 {"booting": "<!DOCTYPE HTML>\n<html..."
                  "not_booting": "Not booting</span></h2>\n<p>These..."}"""
    content = ""
    if path:
        # Read file
        with open(path, encoding="utf-8") as handle:
            content = handle.read()
    else:
        # Download wiki page
        url = "http://wiki.postmarketos.org/wiki/Devices"
        content = urllib.request.urlopen(url).read().decode("utf-8")

    # Split into booting and not booting
    split = content.split("<span class=\"mw-headline\" id=\"Not_booting\">")

    if len(split) != 2:
        print("*** Failed to parse wiki page")
        sys.exit(2)
    return {"booting": split[0], "not_booting": split[1]}


def check_device(device, html, is_booting):
    """:param is_booting: require the device to be in the booting section, not
                          just anywhere in the page (i.e. in the not booting
                          table).
       :returns: True when the device is in the appropriate section."""
    if device in html["booting"]:
        return True
    if device in html["not_booting"]:
        if is_booting:
            print(device + ": still in 'not booting' section (if this is a"
                  " merge request, your device should be in the booting"
                  " section already)")
            return False
        return True

    print(device + ": not in the wiki yet.")
    return False


def main():
    # Parse arguments
    parser = argparse.ArgumentParser()
    parser.add_argument("--booting", help="devices must be in the upper table,"
                        " being in the 'not booting' table below is not"
                        " enough (all devices in pmbootstrap master should be"
                        " in the upper table)", action="store_true")
    parser.add_argument("--path", help="instead of downloading the devices"
                        " page from the wiki, use a local HTML file",
                        default=None)
    args = parser.parse_args()

    # Check all devices
    html = get_wiki_devices_html(args.path)
    error = False
    for device in get_devices():
        if not check_device(device, html, args.booting):
            error = True

    # Ask to adjust the wiki
    if error:
        print("*** Wiki check failed!")
        print("Thank you for porting postmarketOS to a new device! \o/")
        print("")
        print("Now it's time to add some documentation:")
        print("1) Create a device specific wiki page as described here:")
        print("   <https://wiki.postmarketos.org/wiki/Help:Device_Page>")
        print("2) Add your device to the overview matrix:")
        print("   <https://wiki.postmarketos.org/wiki/Devices>")
        print("3) Run these tests again with an empty commit in your PR:")
        print("   $ git commit --allow-empty -m 'run tests again'")
        print("")
        print("Please take the time to do these steps. It will make your")
        print("precious porting efforts visible for others, and allow them")
        print("not only to use what you have created, but also to build upon")
        print("it more easily. Many times one person did a port with basic")
        print("functionallity, and then someone else jumped in and")
        print("contributed major new features.")
        return 1
    else:
        print("*** Wiki check successful!")
    return 0


sys.exit(main())
