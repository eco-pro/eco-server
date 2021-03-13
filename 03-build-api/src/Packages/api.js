const elmServerless = require('@the-sett/serverless-elm-bridge');
//const elmServerless = require('/home/rupert/sc/github/the-sett/elm-serverless/src-bridge/index.js');

const {
  DynamoDBPorts
} = require('../../../shared/js/dynamo.js');

// Import the elm app
const {
  Elm
} = require('./API.elm');

// Use AWS Lambda environment variables to override these values.
const config = {
  buildStatusTable: process.env.buildStatusTable,
  markersTable: process.env.markersTable,
  rootSiteImportsTable: process.env.rootSiteImportsTable,
  buildQueue: process.env.buildQueue,
  buildService: process.env.buildService
};

const app = Elm.Packages.API.init({
  flags: config
});

// Create an AWS Lambda handler which bridges to the Elm app.
module.exports.handler = elmServerless.httpApi({
  app: app,
  requestPort: 'requestPort',
  responsePort: 'responsePort',
});

// Subscribe to DynamoDB Ports.
const dynamoPorts = new DynamoDBPorts();
dynamoPorts.subscribe(app,
  "dynamoGetPort",
  "dynamoPutPort",
  "dynamoDeletePort",
  "dynamoBatchGetPort",
  "dynamoBatchWritePort",
  "dynamoQueryPort",
  "dynamoResponsePort");
