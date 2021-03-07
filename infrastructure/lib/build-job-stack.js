const cdk = require('@aws-cdk/core');
const ec2 = require("@aws-cdk/aws-ec2");
const ecs = require("@aws-cdk/aws-ecs");
const ecs_patterns = require("@aws-cdk/aws-ecs-patterns");
const s3 = require('@aws-cdk/aws-s3');
const sqs = require('@aws-cdk/aws-sqs');
const sst = require('@serverless-stack/resources');

export default class BuildJobStack extends cdk.Stack {
  constructor(scope, id, props) {
    super(scope, id, props);

    // Build Job Queue and Processor.

    // VPC Network Segment.
    const vpc = new ec2.Vpc(this, "eco-vpc", {
      maxAzs: 1
    });

    // Build job processing.
    const queue = new sqs.Queue(this, "buildjob-queue");

    // const cluster = new ecs.Cluster(this, "eco-ecs-cluster", {
    //   vpc: vpc
    // });
    //
    // new ecs_patterns.QueueProcessingFargateService(this, "eco-build-service", {
    //   cluster,
    //   queue,
    //   desiredTaskCount: 1,
    //   image: ecs.ContainerImage.fromRegistry("amazon/amazon-ecs-sample")
    // });
  }
}
