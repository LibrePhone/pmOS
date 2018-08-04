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
import os
import logging
import shutil
import tarfile
import tempfile
import stat

import pmb.helpers.run
import pmb.config
import pmb.config.load
import pmb.parse.apkindex
import pmb.helpers.http
import pmb.parse.version


def read_signature_info(tar):
    """
    Find various information about the signature, that was used to sign
    /sbin/apk.static inside the archive (not to be confused with the normal apk
    archive signature!)

    :returns: (sigfilename, sigkey_path)
    """
    # Get signature filename and key
    prefix = "sbin/apk.static.SIGN.RSA."
    sigfilename = None
    for filename in tar.getnames():
        if filename.startswith(prefix):
            sigfilename = filename
            break
    if not sigfilename:
        raise RuntimeError("Could not find signature filename in apk." +
                           " This means, that your apk file is damaged. Delete it" +
                           " and try again. If the problem persists, fill out a bug" +
                           " report.")
    sigkey = sigfilename[len(prefix):]
    logging.debug("sigfilename: " + sigfilename)
    logging.debug("sigkey: " + sigkey)

    # Get path to keyfile on disk
    sigkey_path = pmb.config.pmb_src + "/keys/" + sigkey
    if "/" in sigkey or not os.path.exists(sigkey_path):
        raise RuntimeError("Invalid signature key: " + sigkey)

    return (sigfilename, sigkey_path)


def extract_temp(tar, sigfilename):
    """
    Extract apk.static and signature as temporary files.
    """
    ret = {
        "apk": {
            "filename": "sbin/apk.static",
            "temp_path": None
        },
        "sig": {
            "filename": sigfilename,
            "temp_path": None
        }
    }
    for ftype in ret.keys():
        member = tar.getmember(ret[ftype]["filename"])

        handle, path = tempfile.mkstemp(ftype, "pmbootstrap")
        handle = open(handle, "wb")
        ret[ftype]["temp_path"] = path
        shutil.copyfileobj(tar.extractfile(member), handle)

        logging.debug("extracted: " + path)
        handle.close()
    return ret


def verify_signature(args, files, sigkey_path):
    """
    Verify the signature with openssl.

    :param files: return value from extract_temp()
    :raises RuntimeError: when verification failed and  removes temp files
    """
    logging.debug("Verify apk.static signature with " + sigkey_path)
    try:
        pmb.helpers.run.user(args, ["openssl", "dgst", "-sha1", "-verify",
                                    sigkey_path, "-signature", files[
                                        "sig"]["temp_path"],
                                    files["apk"]["temp_path"]])
    except BaseException:
        os.unlink(files["sig"]["temp_path"])
        os.unlink(files["apk"]["temp_path"])
        raise RuntimeError("Failed to validate signature of apk.static."
                           " Either openssl is not installed, or the"
                           " download failed. Run 'pmbootstrap zap -hc' to"
                           " delete the download and try again.")


def extract(args, version, apk_path):
    """
    Extract everything to temporary locations, verify signatures and reported
    versions. When everything is right, move the extracted apk.static to the
    final location.
    """
    # Extract to a temporary path
    with tarfile.open(apk_path, "r:gz") as tar:
        sigfilename, sigkey_path = read_signature_info(tar)
        files = extract_temp(tar, sigfilename)

    # Verify signature
    verify_signature(args, files, sigkey_path)
    os.unlink(files["sig"]["temp_path"])
    temp_path = files["apk"]["temp_path"]

    # Verify the version, that the extracted binary reports
    logging.debug("Verify the version reported by the apk.static binary" +
                  " (must match the package version " + version + ")")
    os.chmod(temp_path, os.stat(temp_path).st_mode | stat.S_IEXEC)
    version_bin = pmb.helpers.run.user(args, [temp_path, "--version"],
                                       output_return=True)
    version_bin = version_bin.split(" ")[1].split(",")[0]
    if not version.startswith(version_bin + "-r"):
        os.unlink(temp_path)
        raise RuntimeError("Downloaded apk-tools-static-" + version + ".apk,"
                           " but the apk binary inside that package reports to be"
                           " version: " + version_bin + "! Looks like a downgrade attack"
                           " from a malicious server! Switch the server (-m) and try again.")

    # Move it to the right path
    target_path = args.work + "/apk.static"
    shutil.move(temp_path, target_path)


def download(args, file):
    """
    Download a single file from an Alpine mirror.
    """
    base_url = args.mirror_alpine + "edge/main/" + args.arch_native
    return pmb.helpers.http.download(args, base_url + "/" + file, file)


def init(args):
    """
    Download, verify, extract $WORK/apk.static.
    """
    # Get and parse the APKINDEX
    apkindex = pmb.helpers.repo.alpine_apkindex_path(args, "main")
    index_data = pmb.parse.apkindex.package(args, "apk-tools-static",
                                            indexes=[apkindex])
    version = index_data["version"]

    # Extract and verify the apk-tools-static version
    version_min = pmb.config.apk_tools_static_min_version
    apk_name = "apk-tools-static-" + version + ".apk"
    if pmb.parse.version.compare(version, version_min) == -1:
        raise RuntimeError("Your APKINDEX has an outdated version of"
                           " apk-tools-static (your version: " + version +
                           ", expected at least:" + version_min + "). Please" +
                           " run 'pmbootstrap update'.")

    # Download, extract, verify apk-tools-static
    apk_static = download(args, apk_name)
    extract(args, version, apk_static)


def run(args, parameters):
    pmb.helpers.run.root(args, [args.work + "/apk.static"] + parameters)
