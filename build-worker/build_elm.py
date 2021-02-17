#!/usr/bin/env python3
import requests as req
import re
import zipfile
import json
import hashlib
import os
import subprocess

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
        zip_ref.extractall(".")
        zip_hash = zip_file_md5(zip_ref)

    # Extract the elm.json, and POST it to the package server.
    print("Is it an Elm 19 project? Skip if not.")

    try:
        with open(packageName + "-" + version + "/" + "elm.json") as json_file:
            data = json.load(json_file)

            elmCompilerVersion = data['elm-version']

            if elmCompilerVersion.startswith('0.19.0'):
                print("Compile with Elm 0.19.0")
                os.chdir(packageName + "-" + version)
                elmResult = subprocess.run(["elm", "make", "--docs=docs.json"])

                if elmResult.returncode != 0:
                    report_error(seq, "Failed to compile.")
                    continue

            elif elmCompilerVersion.startswith('0.19.1'):
                print("Compile with Elm 0.19.1")
                os.chdir(packageName + "-" + version)
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
