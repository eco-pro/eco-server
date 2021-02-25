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
import time


def calc_zip_file_sha1(zip_file_name):
    """
    Calculate the MD5 of the .zip file contents.
    """
    blocksize = 1024**2  # 1M chunks

    # Calculate the sha1 of all files in the archive, ignore directories.
    with zipfile.ZipFile(packageName + "-" + version + ".zip", "r") as archive:
        all_files = [x for x in archive.namelist() if not x.endswith('/')]
        all_file_sha1s = []
        for fname in all_files:
            entry = archive.open(fname)
            sha1 = hashlib.sha1()
            while True:
                block = entry.read(blocksize)
                if not block:
                    break
                sha1.update(block)
            all_file_sha1s.append(fname + " " + sha1.hexdigest())

    # Calculate a sha1 over all file sha1s, sorted by filename.
    all_file_sha1s.sort()
    contents_sha1 = hashlib.sha1()
    contents_sha1.update("\n".join(all_file_sha1s).encode("utf-8"))

    # Calculate a sha1 over the .zip file itself
    zip_file_sha1 = hashlib.sha1()
    with open(packageName + "-" + version + ".zip", 'rb') as f:
        while True:
            block = f.read(blocksize)
            if not block:
                break
        zip_file_sha1.update(block)

    return zip_file_sha1.hexdigest(), contents_sha1.hexdigest()


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
    errorResp = req.post("http://localhost:3000/root-site/packages/" + str(seq) + "/error",
                         json={"errorReason": reason})

    if errorResp.status_code == 500:
        print("Server error whilst reporting error.")
        print(errorResp.text)
        quit()


def report_compile_error(seq, version, errors, compileLogUrl, jsonReportUrl, zip_hash, content_hash):
    """
    Send an error message to /packages/{seqNo}/error for a compile error.
    """
    errorResp = req.post("http://localhost:3000/root-site/packages/" + str(seq) + "/error",
                         json={"errorReason": "compile-failed",
                               "compilerVersion": version,
                               "reportJson": errors,
                               "compileLogUrl": compileLogUrl,
                               "jsonReportUrl": jsonReportUrl,
                               "url": "http://packages.eco-pro.org/blah",
                               "sha1ZipArchive": zip_hash,
                               "sha1PackageContents": content_hash})

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


def compile_elm(author, packageName, version, zip_hash, content_hash, workingDir=None):
    print("Compile with Elm 0.19.1")

    timestr = time.strftime("%Y%m%d-%H%M%S")
    log_file_name = timestr + "_" + author + "_" + \
        packageName + "_" + version + "_compile_0.19.1.txt"
    json_report_file_name = timestr + "_" + author + "_" + \
        packageName + "_" + version + "_compile_0.19.1.json"

    # Compile with human readable output logged.
    elmResult = subprocess.run(["elm", "make", "--docs=docs.json"],
                               stdout=subprocess.PIPE,
                               stderr=subprocess.STDOUT,
                               cwd=workingDir)

    with open(log_file_name, "w") as compile_log:
        compile_log.write(elmResult.stdout.decode('utf-8'))

    # If compilation fails, run it again and get the JSON report.
    # The JSON report is trimmed to a summary only, the compile log should
    # be consulted for the full details.
    if elmResult.returncode != 0:
        elmReportResult = subprocess.run(
            ["elm", "make", "--report=json"],
            capture_output=True,
            cwd=workingDir)
        errorString = elmReportResult.stderr.decode('utf-8')
        errorJson = json.loads(errorString, strict=False)

        with open(json_report_file_name, "w") as json_report:
            json_report.write(errorString)

        keysToKeep = ['path', 'type', 'title']
        errorJson = {key: errorJson[key]
                     for key in keysToKeep if key in errorJson}

        report_compile_error(seq = seq,
                             version = "0.19.1",
                             errors = errorJson,
                             compileLogUrl = "http://buildlogs.s3.log/" + log_file_name,
                             jsonReportUrl = "http://buildlogs.s3.log/" + json_report_file_name,
                             zip_hash = zip_hash,
                             content_hash = content_hash)
        return False

    print("Compiled Ok.")
    shutil.rmtree(workingDir + "/elm-stuff")
    os.remove(workingDir + "/docs.json")

    return True


print("=== Eco-Server Elm Package Build Script ===")

start_dir = os.getcwd()

while True:
    os.chdir(start_dir)

    # Check on the package server what job to do next, if any.
    print("\n  What job?")

    resp = req.get("http://localhost:3000/root-site/packages/nextjob")

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
        zipnames = zip_ref.namelist()
        filterednames = [n for n in zipnames if is_elm_package_file(n)]
        for zipname in filterednames:
            zip_ref.extract(zipname, path=author + "/")

    os.remove(filename)

    # Build a .zip of the minimized package.
    print("Building the canonical Elm package as a .zip file.")

    shutil.make_archive(base_name=packageName + "-" + version,
                        format='zip',
                        root_dir=author,
                        base_dir=packageName + "-" + version)

    zip_hash, content_hash = calc_zip_file_sha1(
        packageName + "-" + version + ".zip")

    # Extract the elm.json, and POST it to the package server.
    print("Is it an Elm 19 project? Skip if not.")

    workingDir = author + "/" + packageName + "-" + version

    try:
        with open(workingDir + "/elm.json") as json_file:
            data = json.load(json_file)

            elmCompilerVersion = data['elm-version']

            if elmCompilerVersion.startswith('0.19.0'):
                if compile_elm(author, packageName, version, zip_hash, content_hash, workingDir) == False:
                    continue

            elif elmCompilerVersion.startswith('0.19.1'):
                if compile_elm(author, packageName, version, zip_hash, content_hash, workingDir) == False:
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

    # Copy the package .zip onto its S3 location.

    print("Copying the package onto S3...")

    # aws s3 cp ./${OUTPUT_THUMBS_FILE_NAME} s3://${OUTPUT_S3_PATH}/${OUTPUT_THUMBS_FILE_NAME} --region ${AWS_REGION}

    # POST to the package server to tell it the job is complete.

    print("Letting the package server know where to find it...")
    req.post("http://localhost:3000/root-site/packages/" + str(seq) + "/ready",
             json={"elmJson": data,
                   "url": "http://packages.eco-pro.org/blah",
                   "sha1ZipArchive": zip_hash,
                   "sha1PackageContents": content_hash})

    print("Job done. Try looking for the next job...")
