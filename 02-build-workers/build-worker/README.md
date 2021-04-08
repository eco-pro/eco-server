### Development Testing

Ensure you have Docker installed on your system.

Build the Docker image with the provided Makefile:

    > make

Run the Docker container interactively, using OFFLINE_MODE:

    > docker run -it \
      -e OFFLINE_MODE=true \
      eco-pro/eco-server-build-worker:v1
