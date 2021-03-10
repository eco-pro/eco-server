let clusterArn = process.env.BUILD_CLUSTER_ARN
let serviceName = process.env.BUILD_SERVICE_NAME

var aws = require('aws-sdk');
var ecs = new aws.ECS();

export async function handleAlarm(event, context) {
  console.log("Build Job Scaling Service.");
  console.log(event.Records[0].Sns.Message);

  // Determine which action is to be taken based on the alarm name.
  let message = event.Records[0].Sns.Message;
  let alarmName = JSON.parse(message).AlarmName;
  let action = alarmName.split('#')[1];
  let desiredCount = 0;
  if ("Ready" == action) {
    desiredCount = 1;
  }

  console.log("Setting desiredCount to: " + desiredCount);

  // Set the desired count of the build job service.
  // ARN for build job service.
  // Invoke ecs api to update the service with desired count.
  return await ecs.updateService({
    cluster: clusterArn,
    service: serviceName,
    desiredCount: desiredCount
  }).promise().then(function(data) {
    console.log(data);

    return {
      statusCode: 200,
      body: JSON.stringify({
        status: "successful"
      }),
    };
  }).catch(function(err) {
    console.log(err, err.stack);

    return {
      statusCode: 500,
      body: JSON.stringify({
        status: "error"
      }),
    };
  });
}
