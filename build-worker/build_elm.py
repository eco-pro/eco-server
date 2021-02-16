#!/usr/bin/env python3
import requests as req
import re
import zipfile
import json


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


print("=== Eco-Server Elm Package Build Script ===")

while True:
    # Check on the package server what job to do next, if any.
    print("What job?")

    resp = req.get("http://localhost:3000/nextjob")

    if resp.status_code != 200:
        print("No job.")
        quit()

    job = resp.json()
    seq = job['seq']
    zipUrl = job['zipUrl']
    packageName = job['name']
    author = job['author']
    version = job['version']

    # https://github.com/elm/core/zipball/1.0.0/

    # Download the package .zip from GitHub, and unpack it.
    print("Downloading from GitHub...")
    print(zipUrl)

    resp = req.get(zipUrl, allow_redirects=True)
    filename = getFilename_fromCd(resp.headers.get('content-disposition'))

    if resp.status_code != 200:
        print("No zip file found.")
        req.post("http://localhost:3000/error/" + str(seq))
        continue

    open(filename, 'wb').write(resp.content)

    print("Got " + filename + ", unpacking...")

    with zipfile.ZipFile(filename, "r") as zip_ref:
        zip_ref.extractall(".")

    # Extract the elm.json, and POST it to the package server.
    print("Is it an Elm 19 project? Skip if not.")

    try:
        with open(packageName + "-" + version + "/" + "elm.json") as json_file:
            data = json.load(json_file)

            elmCompilerVersion = data['elm-version']

            if elmCompilerVersion.startswith('0.19.0'):
                print("Compile with Elm 0.19.0")
            elif elmCompilerVersion.startswith('0.19.1'):
                print("Compile with Elm 0.19.1")
            else:
                print("Unsupported Elm version.")
                req.post("http://localhost:3000/error/" + str(seq))
                continue

                print("Found valid elm.json, posting to package server...")

    except IOError:
        print("No " + packageName + "-" + version + "/" + "elm.json")
        req.post("http://localhost:3000/error/" + str(seq))
        continue

    # Copy the package .zip onto its S3 location.

    print("Copying the package onto S3...")

    # aws s3 cp ./${OUTPUT_THUMBS_FILE_NAME} s3://${OUTPUT_S3_PATH}/${OUTPUT_THUMBS_FILE_NAME} --region ${AWS_REGION}

    # POST to the package server to tell it the job is complete.

    print("Letting the package server know where to find it...")
    req.post("http://localhost:3000/ready/" + str(seq), json=data)

    print("Job done. Try looking for the next job...")
