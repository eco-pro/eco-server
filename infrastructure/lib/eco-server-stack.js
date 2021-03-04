const cdk = require('@aws-cdk/core');
const ec2 = require("@aws-cdk/aws-ec2");
const ecs = require("@aws-cdk/aws-ecs");
const ecs_patterns = require("@aws-cdk/aws-ecs-patterns");
const s3 = require('@aws-cdk/aws-s3');

class InfrastructureStack extends cdk.Stack {
  constructor(scope, id, props) {
    super(scope, id, props);

    new s3.Bucket(this, 'elm-packages', {
      versioned: true
    });

    new s3.Bucket(this, 'elm-build-logs', {
      versioned: true
    });

    const vpc = new ec2.Vpc(this, "eco-server-vpc", {
      maxAzs: 1
    });

    const cluster = new ecs.Cluster(this, "eco-ecs-cluster", {
      vpc: vpc
    });

    new ecs.FargateService(this,
      "eco-fargate-service", {
        cluster: cluster,
        desiredCount: 1,
        taskDefinition: {
          compatability: ecs.FARGATE,
          cpu: 256,
          taskDefinition: {
            image: ecs.ContainerImage.fromRegistry("amazon/amazon-ecs-sample")
          },
          memoryLimitMiB: 2048,
          publicLoadBalancer: false
        }
      });
  }
}

module.exports = {
  InfrastructureStack
}
