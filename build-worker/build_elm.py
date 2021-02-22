#!/usr/bin/env python3
import requests as req
import re
import zipfile
import json
import hashlib
import os
import subprocess
import pathlib
import shutil
import sys


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


def report_error(seq, reason):
    """
    Send an error message to /packages/{seqNo}/error
    """
    req.post("http://localhost:3000/packages/" + str(seq) + "/error",
             json={"errorReason": reason})


def report_compile_error(seq, version, errors):
    """
    Send an error message to /packages/{seqNo}/error for a compile error.
    """
    errorResp = req.post("http://localhost:3000/packages/" + str(seq) + "/error",
                         json={"errorReason": "compile-failed",
                               "compilerVersion": version,
                               "compileErrors": errors})

    if errorResp.status_code == 500:
        print("Server error whilst reporting compile error.")
        print(errorResp.text)
        quit()


escaped_glob_tokens_to_re = dict((
    # Order of ``**/`` and ``/**`` in RE tokenization pattern doesn't matter because ``**/`` will be caught first no matter what, making ``/**`` the only option later on.
    # W/o leading or trailing ``/`` two consecutive asterisks will be treated as literals.
    # Edge-case #1. Catches recursive globs in the middle of path. Requires edge case #2 handled after this case.
    ('/\*\*', '(?:/.+?)*'),
    # Edge-case #2. Catches recursive globs at the start of path. Requires edge case #1 handled before this case. ``^`` is used to ensure proper location for ``**/``.
    ('\*\*/', '(?:^.+?/)*'),
    # ``[^/]*?`` is used to ensure that ``*`` won't match subdirs, as with naive ``.*?`` solution.
    ('\*', '[^/]*?'),
    ('\?', '.'),
    ('\[\*\]', '\*'),  # Escaped special glob character.
    ('\[\?\]', '\?'),  # Escaped special glob character.
    # Requires ordered dict, so that ``\[!`` preceded ``\[`` in RE pattern. Needed mostly to differentiate between ``!`` used within character class ``[]`` and outside of it, to avoid faulty conversion.
    ('\[!', '[^'),
    ('\[', '['),
    ('\]', ']'),
))

escaped_glob_replacement = re.compile('(%s)' % '|'.join(
    escaped_glob_tokens_to_re).replace('\\', '\\\\\\'))


def glob_to_re(pattern):
    return escaped_glob_replacement.sub(lambda match: escaped_glob_tokens_to_re[match.group(0)], re.escape(pattern))


def globmatch(path, pattern):
    return re.fullmatch(glob_to_re(pattern), path)


def is_elm_package_file(pathname):
    """
    Matches filepath names that are part of an Elm package, and no others.
    /README.md
    /LICENSE
    /elm.json
    /src/**
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


def compile_elm():
    print("Compile with Elm 0.19.1")
    elmResult = subprocess.run(["elm", "make", "--docs=docs.json"],
                               stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    with open("compile_log_elm_0.19.1.txt", "w") as compile_log:
        compile_log.write(elmResult.stdout.decode('utf-8'))

    if elmResult.returncode != 0:
        elmReportResult = subprocess.run(
            ["elm", "make", "--docs=docs.json", "--report=json"],
            capture_output=True)
        errorString = elmReportResult.stderr.decode('utf-8')

        if sys.getsizeof(errorString) > 4096:
            errorJson = {'path': null,
                         'type': 'error',
                         'title': 'BUILD JSON REPORT TOO LARGE'}
            report_compile_error(seq, "0.19.1", errorJson)
        else:
            errorJson = json.loads(errorString, strict=False)
            report_compile_error(seq, "0.19.1", errorJson)
        return False

    print("Compiled Ok.")
    shutil.rmtree('elm-stuff')
    os.remove("docs.json")

    return True


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
        report_error(seq, "no-github-package")
        continue

    open(filename, 'wb').write(resp.content)

    print("Got " + filename + ", unpacking...")

    with zipfile.ZipFile(filename, "r") as zip_ref:
        zip_hash = zip_file_md5(zip_ref)
        zipnames = zip_ref.namelist()
        filterednames = [n for n in zipnames if is_elm_package_file(n)]
        for zipname in filterednames:
            zip_ref.extract(zipname, path=author + "/")

    os.remove(filename)

    # Extract the elm.json, and POST it to the package server.
    print("Is it an Elm 19 project? Skip if not.")

    try:
        os.chdir(author + "/" + packageName + "-" + version)
    except FileNotFoundError:
        report_error(seq, "package-renamed")
        continue

    try:
        with open("elm.json") as json_file:
            data = json.load(json_file)

            elmCompilerVersion = data['elm-version']

            if elmCompilerVersion.startswith('0.19.0'):
                if compile_elm() == False:
                    continue

            elif elmCompilerVersion.startswith('0.19.1'):
                if compile_elm() == False:
                    continue

            else:
                print("== Error: Unsupported Elm version.")
                report_error(seq, "unsupported-elm-version")
                continue

                print("Found valid elm.json, posting to package server...")

    except IOError:
        print("== Error: No " + packageName + "-" + version + "/" + "elm.json")
        report_error(seq, "not-elm-package")
        continue

    os.chdir(start_dir)

    # Build a .zip of the minimized package.
    print("Building the canonical Elm package as a .zip file.")

    shutil.make_archive(base_name=packageName + "-" + version,
                        format='zip',
                        root_dir=author,
                        base_dir=packageName + "-" + version)

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
