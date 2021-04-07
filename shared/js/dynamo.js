const AWS = require('aws-sdk');

// --- Get a DynamoDB DocumentClient to access it through.
// In serverless offline mode, this will use a local server.

if (process.env.IS_OFFLINE) {
  console.log("IS_OFFLINE");
  AWS.config.update({
    region: 'localhost',
    endpoint: "http://localhost:4566"
  });
}

let DocumentClient = new AWS.DynamoDB.DocumentClient();

// --- DynamoDB Operations.

let dynamoGet = (responsePort, correlationId, interopId, params) => {
  DocumentClient.get(params, (error, result) => {
    var getResponse;

    if (error) {
      getResponse = {
        type_: "Error",
        errorMsg: JSON.stringify(error, null, 2) + "\n" + JSON.stringify(params, null, 2)
      };
    } else if (Object.entries(result).length === 0) {
      getResponse = {
        type_: "ItemNotFound"
      }
    } else {
      getResponse = {
        type_: "Item",
        item: result
      }
    }

    responsePort.send([correlationId, interopId, getResponse]);
  });
}

let dynamoPut = (responsePort, correlationId, interopId, params) => {
  DocumentClient.put(params, (error, result) => {
    var putResponse;

    if (error) {
      putResponse = {
        type_: "Error",
        errorMsg: JSON.stringify(error, null, 2) + "\n" + JSON.stringify(params, null, 2)
      };
    } else {
      putResponse = {
        type_: "Ok"
      }
    }

    responsePort.send([correlationId, interopId, putResponse]);
  });
}

let dynamoDelete = (responsePort, correlationId, interopId, params) => {
  DocumentClient.delete(params, (error, result) => {
    var deleteResponse;

    if (error) {
      deleteResponse = {
        type_: "Error",
        errorMsg: JSON.stringify(error, null, 2) + "\n" + JSON.stringify(params, null, 2)
      };
    } else {
      deleteResponse = {
        type_: "Ok"
      }
    }

    responsePort.send([correlationId, interopId, deleteResponse]);
  });
}

let dynamoBatchGet = (responsePort, correlationId, interopId, params) => {
  DocumentClient.batchGet(params, (error, result) => {
    var getResponse;

    if (error) {
      getResponse = {
        type_: "Error",
        errorMsg: JSON.stringify(error, null, 2) + "\n" + JSON.stringify(params, null, 2)
      };
    } else if (Object.entries(result).length === 0) {
      getResponse = {
        type_: "Item",
        item: []
      }
    } else {
      getResponse = {
        type_: "Item",
        item: result
      }
    }

    responsePort.send([correlationId, interopId, getResponse]);
  });
}

let dynamoBatchWrite = (responsePort, correlationId, interopId, params) => {
  DocumentClient.batchWrite(params, (error, result) => {
    var putResponse;

    if (error) {
      putResponse = {
        type_: "Error",
        errorMsg: JSON.stringify(error, null, 2) + "\n" + JSON.stringify(params, null, 2)
      };
    } else {
      putResponse = {
        type_: "Ok"
      }
    }

    responsePort.send([correlationId, interopId, putResponse]);
  });
}

let dynamoQuery = (responsePort, correlationId, interopId, params) => {
  DocumentClient.query(params, (error, result) => {
    var getResponse;

    if (error) {
      getResponse = {
        type_: "Error",
        errorMsg: JSON.stringify(error, null, 2) + "\n" + JSON.stringify(params, null, 2)
      };
    } else if (Object.entries(result).length === 0) {
      getResponse = {
        type_: "Items",
        items: []
      }
    } else {
      getResponse = {
        type_: "Items",
        items: result.Items
      }
    }

    if (result.LastEvaluatedKey !== undefined) {
      getResponse.lastEvaluatedKey = result.LastEvaluatedKey;
    }

    responsePort.send([correlationId, interopId, getResponse]);
  });
}


// --- Provide a function for wiring all the ports up by Elm port name.

var DynamoDBPorts = function() {};

DynamoDBPorts.prototype.subscribe =
  function(
    app,
    dynamoGetPortName,
    dynamoPutPortName,
    dynamoDeletePortName,
    dynamoBatchGetPortName,
    dynamoBatchWritePortName,
    dynamoQueryPortName,
    dynamoResponsePortName

  ) {

    if (!dynamoGetPortName)
      dynamoGetPortName = "dynamoGetPort";

    if (!dynamoPutPortName)
      dynamoPutPortName = "dynamoPutPort";

    if (!dynamoDeletePortName)
        dynamoDeletePortName = "dynamoDeletePort";

    if (!dynamoBatchGetPortName)
      dynamoBatchGetPortName = "dynamoBatchGetPort";

    if (!dynamoBatchWritePortName)
      dynamoBatchWritePortName = "dynamoBatchWritePort";

    if (!dynamoQueryPortName)
      dynamoQueryPortName = "dynamoQueryPort";

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

    if (app.ports[dynamoDeletePortName]) {
      app.ports[dynamoDeletePortName].subscribe(args => {
        dynamoDelete(dynamoResponsePort, args[0], args[1], args[2]);
      });
    } else {
      console.warn("The " + dynamoDeletePortName + " port is not connected.");
    }

    if (app.ports[dynamoBatchGetPortName]) {
      app.ports[dynamoBatchGetPortName].subscribe(args => {
        dynamoBatchGet(dynamoResponsePort, args[0], args[1], args[2]);
      });
    } else {
      console.warn("The " + dynamoBatchGetPortName + " port is not connected.");
    }

    if (app.ports[dynamoBatchWritePortName]) {
      app.ports[dynamoBatchWritePortName].subscribe(args => {
        dynamoBatchWrite(dynamoResponsePort, args[0], args[1], args[2]);
      });
    } else {
      console.warn("The " + dynamoPutPortName + " port is not connected.");
    }

    if (app.ports[dynamoQueryPortName]) {
      app.ports[dynamoQueryPortName].subscribe(args => {
        dynamoQuery(dynamoResponsePort, args[0], args[1], args[2]);
      });
    } else {
      console.warn("The " + dynamoPutPortName + " port is not connected.");
    }
  };

module.exports = {
  DynamoDBPorts
};
