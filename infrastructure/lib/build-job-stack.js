import { CfnOutput, RemovalPolicy, Duration } from "@aws-cdk/core";
const ec2 = require("@aws-cdk/aws-ec2");
const ecs = require("@aws-cdk/aws-ecs");
const ecs_patterns = require("@aws-cdk/aws-ecs-patterns");
const s3 = require('@aws-cdk/aws-s3');
const sqs = require('@aws-cdk/aws-sqs');
const sst = require('@serverless-stack/resources');
import { DockerImageAsset } from '@aws-cdk/aws-ecr-assets';
const path = require('path');
import * as cloudwatch from '@aws-cdk/aws-cloudwatch';
import * as sns from '@aws-cdk/aws-sns';
import { SnsEventSource } from '@aws-cdk/aws-lambda-event-sources';
const iam = require('@aws-cdk/aws-iam');

export default class BuildJobStack extends sst.Stack {
  constructor(scope, id, props) {
    super(scope, id, props);

    const app = this.node.root;

    // Build Job Queue and Processor.
    const buildJobImage =
      ecs.ContainerImage.fromAsset(path.join(__dirname, '..', '..', 'build-worker'));

    // VPC Network Segment.
    const vpc = new ec2.Vpc(this, "vpc", {
      maxAzs: 1
    });

    // Build job processing.
    const queue = new sqs.Queue(this, "build-queue");

    new CfnOutput(this, "build-queue-name", {
     value: queue.queueName,
     exportName: app.logicalPrefixedName("BuildQueueName")
    });

    new CfnOutput(this, "build-queue-arn", {
     value: queue.queueArn,
     exportName: app.logicalPrefixedName("BuildQueueArn")
    });

    const logging = new ecs.AwsLogDriver({
      streamPrefix: "eco-build-service"
    });

    const cluster = new ecs.Cluster(this, "ecs-cluster", {
      vpc: vpc
    });

    const buildService = new ecs_patterns.QueueProcessingFargateService(this, "ecobuild-service", {
      serviceName: "BuildService",
      cluster: cluster,
      queue: queue,
      desiredTaskCount: 0,
      maxScalingCapacity: 1,
      image: buildJobImage
    });

    new CfnOutput(this, "build-service-name", {
     value: buildService.service.serviceName,
     exportName: app.logicalPrefixedName("BuildServiceName")
    });

    new CfnOutput(this, "build-service-arn", {
     value: buildService.service.serviceArn,
     exportName: app.logicalPrefixedName("BuildServiceArn")
    });

    // Build Job Queue and scaling based on queue size.
    // If the queue shrinks to zero, no build jobs will run.
    // If the queue grows to one or more, one build job will run.
    const jobScalingTopic = new sns.Topic(this, 'job-scale', {
         displayName: 'Topic for Scaling Build Job Fargate Tasks'
    });

    const scalingHandler = new sst.Function(this, "scaling-handler", {
      handler: "src/scaling.handleAlarm",
      environment: {
        BUILD_CLUSTER_ARN: cluster.clusterArn,
        BUILD_SERVICE_ARN: buildService.service.serviceArn,
        BUILD_SERVICE_NAME: buildService.service.serviceName
      },
    });

    scalingHandler.addEventSource(new SnsEventSource(jobScalingTopic, {}));

    const scalingPolicy = new iam.PolicyStatement();
    scalingPolicy.addActions("ecs:UpdateService");
    scalingPolicy.addResources("*");

    scalingHandler.addToRolePolicy(scalingPolicy);

    const jobsReadyAlarm = new cloudwatch.Alarm(this, 'jobs-ready', {
      alarmName: "BuildJobQueue#Ready",
      metric: queue.metric("ApproximateNumberOfMessagesVisible"),
      threshold: 1,
      comparisonOperator: cloudwatch.ComparisonOperator.GREATER_THAN_OR_EQUAL_TO_THRESHOLD,
      evaluationPeriods: 1,
      datapointsToAlarm: 1,
      period: Duration.seconds(60)
    });

    jobsReadyAlarm.addAlarmAction({
      bind(scope, alarm) {
        return { alarmActionArn: jobScalingTopic.topicArn };
      }
    });

    const jobsNoneAlarm = new cloudwatch.Alarm(this, 'jobs-none', {
      alarmName: "BuildJobQueue#Empty",
      metric: queue.metric("ApproximateNumberOfMessagesVisible"),
      threshold: 1,
      comparisonOperator: cloudwatch.ComparisonOperator.LESS_THAN_THRESHOLD,
      evaluationPeriods: 1,
      datapointsToAlarm: 1,
      period: Duration.seconds(60)
    });

    jobsNoneAlarm.addAlarmAction({
      bind(scope, alarm) {
        return { alarmActionArn: jobScalingTopic.topicArn };
      }
    });
  }
}
