const AWS = require('aws-sdk');

// --- Get a DynamoDB DocumentClient to access it through.
// In serverless offline mode, this will use a local server.

if (process.env.IS_OFFLINE) {
  AWS.config.update({
    region: 'localhost',
    endpoint: "http://localhost:8000"
  });
}

let DocumentClient = new AWS.DynamoDB.DocumentClient();

// --- DynamoDB Operations.

let dynamoGet = (responsePort, correlationId, interopId, params) => {
  console.log("dynamoGet: Invoked");
  console.log(params);

  DocumentClient.get(params, (error, result) => {
    if (error) {
      console.log("dynamoGet: Error");
      console.error(error);
      responsePort.send([correlationId, interopId, "error"]);
    } else {
      console.log("dynamoGet: Ok")
      responsePort.send([correlationId, interopId, "ok"]);
    }
  });
}

let dynamoPut = (responsePort, correlationId, interopId, params) => {
  console.log("dynamoPut: Invoked");
  console.log(params);

  DocumentClient.put(params, (error, result) => {
    if (error) {
      console.log("dynamoPut: Error");
      console.error(error);
      responsePort.send([correlationId, interopId, "error"]);
    } else {
      console.log("dynamoPut: Ok")
      responsePort.send([correlationId, interopId, result]);
    }
  });
}

let dynamoUpdate = (responsePort, correlationId, interopId, params) => {
  console.log("dynamoUpdate: Invoked");
  console.log(params);

  DocumentClient.get(params, (error, result) => {
    if (error) {
      console.log("dynamoUpdate: Error");
      console.error(error);
      responsePort.send([correlationId, interopId, "error"]);
    } else {
      console.log("dynamoUpdate: Ok")
      responsePort.send([correlationId, interopId, result]);
    }
  });
}

// --- Provide a function for wiring all the ports up by Elm port name.

var DynamoDBPorts = function() {};

DynamoDBPorts.prototype.subscribe =
  function(
    app,
    dynamoGetPortName,
    dynamoPutPortName,
    dynamoResponsePortName
  ) {

    if (!dynamoGetPortName)
      dynamoGetPortName = "dynamoGetPort";

    if (!dynamoPutPortName)
      dynamoPutPortName = "dynamoPutPort";

    if (!dynamoResponsePortName)
      dynamoResponsePortName = "dynamoResponsePort";

    if (app.ports[dynamoResponsePortName]) {
      var dynamoResponsePort = app.ports[dynamoResponsePortName];
    } else {
      console.warn("The " + dynamoResponsePortName + " port is not connected.");
    }

    if (app.ports[dynamoGetPortName]) {
      app.ports[dynamoGetPortName].subscribe(args => {
        dynamoGet(dynamoResponsePort, args[0], args[1], args[2]);
      });
    } else {
      console.warn("The " + dynamoGetPortName + " port is not connected.");
    }

    if (app.ports[dynamoPutPortName]) {
      app.ports[dynamoPutPortName].subscribe(args => {
        dynamoPut(dynamoResponsePort, args[0], args[1], args[2]);
      });
    } else {
      console.warn("The " + dynamoPutPortName + " port is not connected.");
    }
  };

module.exports = {
  DynamoDBPorts
};
