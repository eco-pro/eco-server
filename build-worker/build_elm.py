#!/usr/bin/env python3
import requests as req

print("=== Eco-Server Elm Package Build Script ===")

# Check on the package server what job to do next, if any.
print("What job?")

resp = req.get("http://localhost:3000/nextjob")
status = resp.status_code

if status != 200:
  print("No job.")
  quit()

job = resp.json()
print(status)
print(job)
print(job['zipUrl'])

# https://github.com/elm/core/zipball/1.0.0/

# Download the package .zip from GitHub, and unpack it.
print("Downloading from GitHub...")

print("Got the .zip, unpacking...")

# Extract the elm.json, and POST it to the package server.

print("Is it an Elm 19 project? Skip if not.")

print("Found elm.json, posting to package server...")

# Copy the package .zip onto its S3 location.

print("Copying the package onto S3...")

#aws s3 cp ./${OUTPUT_THUMBS_FILE_NAME} s3://${OUTPUT_S3_PATH}/${OUTPUT_THUMBS_FILE_NAME} --region ${AWS_REGION}

# POST to the package server to tell it the job is complete.

print("Letting the package server know where to find it...")

print("Job done. Try looking for the next job...")
