export async function handleAlarm(event, context) {
  console.log("Build Job Scaling Service.");
  console.log(event.Records[0].Sns.Message);
  return {
    statusCode: 200,
    body: JSON.stringify({ status: "successful" }),
  };
}
