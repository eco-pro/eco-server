#!/bin/sh

echo "=== Eco-Server Elm Package Build Script ==="

# Check on the package server what job to do next, if any.
echo "What job?"

# Download the package .zip from GitHub, and unpack it.
echo "Downloading from GitHub..."

echo "Got the .zip, unpacking..."

# Extract the elm.json, and POST it to the package server.

echo "Found elm.json, posting to package server..."

# Copy the package .zip onto its S3 location.

echo "Copying the package onto S3..."

#aws s3 cp ./${OUTPUT_THUMBS_FILE_NAME} s3://${OUTPUT_S3_PATH}/${OUTPUT_THUMBS_FILE_NAME} --region ${AWS_REGION}

# POST to the package server to tell it the job is complete.

echo "Letting the package server know where to find it..."

echo "Job done. Try looking for the next job..."
