import { CfnOutput, RemovalPolicy, Duration, Fn } from "@aws-cdk/core";
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
const servicediscovery = require('@aws-cdk/aws-servicediscovery');
import { Effect, PolicyStatement } from '@aws-cdk/aws-iam';
import { RetentionDays } from '@aws-cdk/aws-logs';

export default class BuildJobStack extends sst.Stack {
  constructor(scope, id, props) {
    super(scope, id, props);

    const app = this.node.root;

    // Loop up the VPC where this is to be deployed.
    const vpc = ec2.Vpc.fromLookup(this, "vpc", {
      tags: {
        'vpc-name': 'eco-server-vpc'
      }
    });

    // Build Job.
    const buildJobImage =
      ecs.ContainerImage.fromAsset(path.join(__dirname, '..', '..', 'build-worker'));

    const logging = new ecs.AwsLogDriver({
      streamPrefix: "eco-build-service",
      logRetention: RetentionDays.ONE_DAY
    });

    const cluster = new ecs.Cluster(this, "ecs-cluster", {
      vpc: vpc
    });

    const buildTask = new ecs.FargateTaskDefinition(this, "build-task", {});

    buildTask.addContainer("build-service-task", {
      image: buildJobImage,
      logging: logging,
      environment: {
        'PACKAGE_BUCKET_NAME': Fn.importValue(app.logicalPrefixedName('ElmPackageBucketName')),
        'BUILD_LOGS_BUCKET_NAME': Fn.importValue(app.logicalPrefixedName('ElmBuildLogsBucketName'))
      }
    });

    buildTask.addToTaskRolePolicy(
      new PolicyStatement({
        effect: Effect.ALLOW,
        resources: ['*'],
        actions: ['servicediscovery:DiscoverInstances']
      }));

    buildTask.addToTaskRolePolicy(
      new PolicyStatement({
        effect: Effect.ALLOW,
        resources: [
          Fn.importValue(app.logicalPrefixedName('ElmPackageBucketArn')),
          Fn.importValue(app.logicalPrefixedName('ElmPackageBucketArn')) + "/*",
          Fn.importValue(app.logicalPrefixedName('ElmBuildLogsBucketArn')),
          Fn.importValue(app.logicalPrefixedName('ElmBuildLogsBucketArn')) + "/*"
        ],
        actions: ['s3:*']
      }));

    // buildTask.addToTaskRolePolicy(
    //   new PolicyStatement({
    //     effect: Effect.ALLOW,
    //     resources: [ '*' ],
    //     actions: [
    //       'logs:CreateLogStream',
    //       'logs:PutLogEvents']
    //   }));
    //
    // buildTask.addToExecutionRolePolicy(
    //   new PolicyStatement({
    //     effect: Effect.ALLOW,
    //     resources: [ '*' ],
    //     actions: [
    //       'ecr:BatchCheckLayerAvailability',
    //       'ecr:GetDownloadUrlForLayer',
    //       'ecr:BatchGetImage',
    //       'ecr:GetAuthorizationToken']
    //   }));
    //
    // buildTask.addToExecutionRolePolicy(
    //   new PolicyStatement({
    //     effect: Effect.ALLOW,
    //     resources: [ '*' ],
    //     actions: [
    //       'logs:CreateLogStream',
    //       'logs:PutLogEvents']
    //   }));
    //
    // buildTask.addToExecutionRolePolicy(
    //   new PolicyStatement({
    //     effect: Effect.ALLOW,
    //     resources: [ '*' ],
    //     actions: [
    //       "kms:*",
    //       "secretsmanager:*",
    //       "ssm:*",
    //       "s3:*",
    //       "ecr:*",
    //       "ecs:*",
    //       "ec2:*"
    //   ]
    // }));

    new CfnOutput(this, "build-task-arn", {
      value: buildTask.taskDefinitionArn,
      exportName: app.logicalPrefixedName("BuildTaskArn")
    });

    // const queue = new sqs.Queue(this, "build-queue");
    //
    // new CfnOutput(this, "build-queue-name", {
    //  value: queue.queueName,
    //  exportName: app.logicalPrefixedName("BuildQueueName")
    // });
    //
    // new CfnOutput(this, "build-queue-arn", {
    //  value: queue.queueArn,
    //  exportName: app.logicalPrefixedName("BuildQueueArn")
    // });
  }
}
