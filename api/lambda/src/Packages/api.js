const elmServerless = require('@the-sett/serverless-elm-bridge');
//const elmServerless = require('/home/rupert/sc/github/the-sett/elm-serverless/src-bridge/index.js');

const { DynamoDBPorts } = require('./dynamo.js');

// Import the elm app
const { Elm } = require('./API.elm');
const app = Elm.Packages.API.init();

// Create an AWS Lambda handler which bridges to the Elm app.
module.exports.handler = elmServerless.httpApi({
  app: app,
  requestPort: 'requestPort',
  responsePort: 'responsePort',
});

// Subscribe to DynamoDB Ports.
const dynamoPorts = new DynamoDBPorts();
dynamoPorts.subscribe(app, "dynamoPut", "dynamoOk");
