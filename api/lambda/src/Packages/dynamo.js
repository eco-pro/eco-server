const AWS = require('aws-sdk');

// In offline mode, use DynamoDB local server
let DocumentClient = null;

if (process.env.IS_OFFLINE) {
  AWS.config.update({
    region: 'localhost',
    endpoint: "http://localhost:8000"
  });
}

// Get a handle to access DynamoDB through.
DocumentClient = new AWS.DynamoDB.DocumentClient();

var DynamoDBPorts = function() {};

DynamoDBPorts.prototype.subscribe =
  function(app, upsertPackageSeqPortName, dynamoOkPortName) {

    if (!upsertPackageSeqPortName) upsertPackageSeqPortName = "getItem";

    if (app.ports[dynamoOkPortName]) {

      var dynamoOkPort = app.ports[dynamoOkPortName];

      if (app.ports[upsertPackageSeqPortName]) {
        app.ports[upsertPackageSeqPortName].subscribe(args => {
          const connectionId = args[0];
          const seqNo = args[1];

          console.log("Save seq no: " + seqNo);
          dynamoOkPort.send([connectionId, "ok"]);
        });
      } else {
        console.warn("The " + upsertPackageSeqPortName + " port is not connected.");
      }

    } else {
      console.warn("The " + dynamoOkPortName + " port is not connected.");
    }
  };


module.exports = {
  DynamoDBPorts
};
