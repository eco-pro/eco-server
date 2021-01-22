const elmServerless = require('@the-sett/serverless-elm-bridge');
//const elmServerless = require('/home/rupert/sc/github/the-sett/elm-serverless/src-bridge/index.js');

// Import the elm app
const { Elm } = require('./API.elm');

// Create an AWS Lambda handler which bridges to the Elm app.
module.exports.handler = elmServerless.httpApi({
  app: Elm.Packages.API.init(),
  requestPort: 'requestPort',
  responsePort: 'responsePort',
});
