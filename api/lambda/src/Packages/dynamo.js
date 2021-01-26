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
  function(app, dynamoPutPortName, dynamoOkPortName) {

    if (!dynamoPutPortName) dynamoPutPortName = "dynamoPut";

    if (app.ports[dynamoOkPortName]) {

      var dynamoOkPort = app.ports[dynamoOkPortName];

      if (app.ports[dynamoPutPortName]) {
        app.ports[dynamoPutPortName].subscribe(args => {
          const connectionId = args[0];
          const params = args[1];

          console.log("dynamoPut: Invoked");
          console.log(params);

          DocumentClient.put(params, (error, result) => {
            if (error) {
              console.log("dynamoPut: Error");
              console.error(error);
              dynamoOkPort.send([connectionId, "error"]);
              return;
            }

            console.log("dynamoPut: Ok")
            dynamoOkPort.send([connectionId, "ok"]);
          });
        });
      } else {
        console.warn("The " + dynamoPutPortName + " port is not connected.");
      }

    } else {
      console.warn("The " + dynamoOkPortName + " port is not connected.");
    }
  };


module.exports = {
  DynamoDBPorts
};
