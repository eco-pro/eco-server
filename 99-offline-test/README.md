### Install localstack

https://github.com/localstack/localstack is needed to run the test stack
offline. Instructions on installation are available on its GitHub README.

To start it running and deploy the test database run:

    > docker run -it \
      -p 4566:4566 \
      -e SERVICES="dynamodb,s3" \
      -e DEBUG=1 \
      -e DATA_DIR="/tmp/localstack/data" \
      -v ${HOME}/data/localstack:/tmp/localstack \
      localstack/localstack

    > npx sls deploy --stage local

The dynamodb web shell should be available at: http://localhost:4566/shell/
