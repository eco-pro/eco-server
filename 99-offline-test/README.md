### Install localstack

https://github.com/localstack/localstack is needed to run the test stack
offline. Instructions on installation are available on its GitHub README.

To start it running and deploy the test database run:

    > docker run -it \
      -p 4566:4566 \
      -e DEBUG=1 \
      -e DATA_DIR="/tmp/localstack/data" \
      -v ${HOME}/data/localstack:/tmp/localstack \
      --name localstack_main \
      localstack/localstack

    > npx sls deploy

The dynamodb web shell should be available at: http://localhost:4566/shell/

The `npx sls deploy` command can also be run without starting docker first,
and it will automatically start the docker localstack container. The advantage
of doing it explicitly as above, is that the data directory gets mapped to
`${HOME}/data/localstack` and persisted between restarts.
