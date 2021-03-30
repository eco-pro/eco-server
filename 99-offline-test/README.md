### Install localstack

https://github.com/localstack/localstack is needed to run the test stack
offline. Instructions on installation are available on its GitHub README.

To start it running and deploy the test database run:

    > npx sls deploy --stage local

The first time this is run, you should see some logs confirming that its docker image is being started.
