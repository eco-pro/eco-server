const elmServerless = require('@the-sett/serverless-elm-bridge');

const { Elm } = require('./API.elm');

module.exports.handler = elmServerless.httpApi({
  app: Elm.Forms.API.init(),
});
