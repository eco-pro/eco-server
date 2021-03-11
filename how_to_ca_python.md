# How to run the build.

## Dev testing

Install mitmproxy.

Run mitmproxy to intercept calls to the package.elm-lang.org site:

    mitmproxy --ssl-insecure -M '|https://package.elm-lang.org/|http://localhost:3000/v1/'

Run the python build script:

    mkdir tmp
    cd tmp

    AWS_ACCESS_KEY_ID=S3RVER \
    AWS_SECRET_ACCESS_KEY=S3RVER \
    PACKAGE_API_ROOT=http://localhost:3000/ \
    S3_ENDPOINT=http://localhost:4569/ \
    https_proxy=http://127.0.0.1:8080 \
    REQUESTS_CA_BUNDLE=~/.mitmproxy/mitmproxy-ca-cert.pem \
    ../build_elm.py

## Testing the Docker image

The build script is dockerized as it will be run this way under Fargate.

To test the docker container locally:

    make

    docker run \
    --network="host" \
    -e AWS_ACCESS_KEY_ID=S3RVER \
    -e AWS_SECRET_ACCESS_KEY=S3RVER \
    -e PACKAGE_API_ROOT=http://localhost:3000/ \
    -e S3_ENDPOINT=http://localhost:4569/ \
    eco-pro/eco-server-build-worker:v1
