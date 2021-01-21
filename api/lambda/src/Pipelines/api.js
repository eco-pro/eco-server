const elmServerless = require('@the-sett/serverless-elm-bridge');
const rc = require('rc');

const { Elm } = require('./API.elm');

// Use AWS Lambda environment variables to override these values
// See the npm rc package README for more details
const config = rc('demoPipelines', {
  cors: {
    origin: '*',
    methods: 'get,post,options',
  },
});

module.exports.handler = elmServerless.httpApi({
  app: Elm.Pipelines.API.init({ flags: config }),
});
