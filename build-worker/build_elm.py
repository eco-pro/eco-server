#!/usr/bin/env python3
import requests as req
import re
import zipfile
import json
import hashlib
import os
import subprocess
import pathlib

def zip_file_md5(archive):
    """
    Calculate the MD5 of the .zip file contents.
    """
    blocksize = 1024**2  # 1M chunks
    for fname in archive.namelist():
        entry = archive.open(fname)
        md5 = hashlib.md5()
        while True:
            block = entry.read(blocksize)
            if not block:
                break
            md5.update(block)
    return md5.hexdigest()


def getFilename_fromCd(cd):
    """
    Get filename from content-disposition
    """
    if not cd:
        return None
    fname = re.findall('filename=(.+)', cd)
    if len(fname) == 0:
        return None
    return fname[0]


def report_error(seq, errorMsg):
    """
    Send an error message to /packages/{seqNo}/error
    """
    req.post("http://localhost:3000/packages/" + str(seq) + "/error",
             json={"errorMsg": errorMsg})

escaped_glob_tokens_to_re = dict((
    # Order of ``**/`` and ``/**`` in RE tokenization pattern doesn't matter because ``**/`` will be caught first no matter what, making ``/**`` the only option later on.
    # W/o leading or trailing ``/`` two consecutive asterisks will be treated as literals.
    ('/\*\*', '(?:/.+?)*'), # Edge-case #1. Catches recursive globs in the middle of path. Requires edge case #2 handled after this case.
    ('\*\*/', '(?:^.+?/)*'), # Edge-case #2. Catches recursive globs at the start of path. Requires edge case #1 handled before this case. ``^`` is used to ensure proper location for ``**/``.
    ('\*', '[^/]*?'), # ``[^/]*?`` is used to ensure that ``*`` won't match subdirs, as with naive ``.*?`` solution.
    ('\?', '.'),
    ('\[\*\]', '\*'), # Escaped special glob character.
    ('\[\?\]', '\?'), # Escaped special glob character.
    ('\[!', '[^'), # Requires ordered dict, so that ``\[!`` preceded ``\[`` in RE pattern. Needed mostly to differentiate between ``!`` used within character class ``[]`` and outside of it, to avoid faulty conversion.
    ('\[', '['),
    ('\]', ']'),
))

escaped_glob_replacement = re.compile('(%s)' % '|'.join(escaped_glob_tokens_to_re).replace('\\', '\\\\\\'))

def glob_to_re(pattern):
    return escaped_glob_replacement.sub(lambda match: escaped_glob_tokens_to_re[match.group(0)], re.escape(pattern))

def globmatch(path, pattern):
    return re.fullmatch(glob_to_re(pattern), path)

def is_elm_package_file(pathname):
    """
    Matches filepath names that are part of a .elm package, and no others.
    package/README.md
    package/LICENSE
    package/elm.json
    package/src/**/*.elm
    """
    if globmatch(pathname, "*/README.md"):
        return True
    elif globmatch(pathname, "*/LICENSE"):
        return True
    elif globmatch(pathname, "*/elm.json"):
        return True
    elif globmatch(pathname, "*/src/**"):
        return True
    else:
        return False

print("=== Eco-Server Elm Package Build Script ===")

start_dir = os.getcwd()

while True:
    os.chdir(start_dir)

    # Check on the package server what job to do next, if any.
    print("\n  What job?")

    resp = req.get("http://localhost:3000/packages/nextjob")

    if resp.status_code != 200:
        print("No jobs. All done.")
        quit()

    job = resp.json()
    seq = job['seq']
    zipUrl = job['zipUrl']
    packageName = job['name']
    author = job['author']
    version = job['version']

    # Download the package .zip from GitHub, and unpack it.
    print("Downloading from GitHub...")
    print(zipUrl)

    resp = req.get(zipUrl, allow_redirects=True)
    filename = getFilename_fromCd(resp.headers.get('content-disposition'))

    if resp.status_code != 200:
        print("== Error: No zip file found.")
        report_error(seq, "No zip file found.")
        continue

    open(filename, 'wb').write(resp.content)

    print("Got " + filename + ", unpacking...")

    with zipfile.ZipFile(filename, "r") as zip_ref:
        zip_hash = zip_file_md5(zip_ref)
        zipnames = zip_ref.namelist()
        filterednames = [n for n in zipnames if is_elm_package_file(n)]
        for zipname in filterednames:
                zip_ref.extract(zipname, path = author + "/")

    # Extract the elm.json, and POST it to the package server.
    print("Is it an Elm 19 project? Skip if not.")

    try:
        with open(author + "/" + packageName + "-" + version + "/" + "elm.json") as json_file:
            data = json.load(json_file)

            elmCompilerVersion = data['elm-version']

            if elmCompilerVersion.startswith('0.19.0'):
                print("Compile with Elm 0.19.0")
                os.chdir(author + "/" + packageName + "-" + version)
                elmResult = subprocess.run(["elm", "make", "--docs=docs.json"])

                if elmResult.returncode != 0:
                    report_error(seq, "Failed to compile.")
                    continue

            elif elmCompilerVersion.startswith('0.19.1'):
                print("Compile with Elm 0.19.1")
                os.chdir(author + "/" + packageName + "-" + version)
                elmResult = subprocess.run(["elm", "make", "--docs=docs.json"])

                if elmResult.returncode != 0:
                    report_error(seq, "Failed to compile.")
                    continue

            else:
                print("== Error: Unsupported Elm version.")
                report_error(seq, "Unsupported Elm version.")
                continue

                print("Found valid elm.json, posting to package server...")

    except IOError:
        print("== Error: No " + packageName + "-" + version + "/" + "elm.json")
        report_error(seq, "No 'elm.json' file.")
        continue

    # Copy the package .zip onto its S3 location.

    print("Copying the package onto S3...")

    # aws s3 cp ./${OUTPUT_THUMBS_FILE_NAME} s3://${OUTPUT_S3_PATH}/${OUTPUT_THUMBS_FILE_NAME} --region ${AWS_REGION}

    # POST to the package server to tell it the job is complete.

    print("Letting the package server know where to find it...")
    req.post("http://localhost:3000/packages/" + str(seq) + "/ready",
             json={"elmJson": data,
                   "packageUrl": "http://packages.eco-pro.org/blah",
                   "md5": zip_hash})

    print("Job done. Try looking for the next job...")
