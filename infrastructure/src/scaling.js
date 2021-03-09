export async function handleAlarm(event, context) {
  console.log("Build Job Scaling Service.");
  console.log(event.Records[0].Sns.Message);

  // Determine which action is to be taken based on the alarm name.

  // Set the desired count of the build job service.
  // ARN for build job service.
  // Invoke ecs api to update the service with desired count.

  return {
    statusCode: 200,
    body: JSON.stringify({ status: "successful" }),
  };
}
