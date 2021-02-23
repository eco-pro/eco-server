var params = {
    TableName: 'dev-eco-buildstatus',
    KeyConditionExpression: 'label = :label',
    ExpressionAttributeValues: {
      ':label': 'error'
    }
};
docClient.query(params, function(err, data) {
    if (err) ppJson(err); // an error occurred
    else ppJson(data); // successful response
});
