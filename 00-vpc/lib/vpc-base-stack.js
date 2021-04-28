import { CfnOutput, RemovalPolicy, Duration, Tags } from '@aws-cdk/core';
import { Vpc, SubnetType, GatewayVpcEndpointAwsService, InterfaceVpcEndpointAwsService } from '@aws-cdk/aws-ec2';
import * as servicediscovery from '@aws-cdk/aws-servicediscovery';
import * as sst from '@serverless-stack/resources';

/*
Set up the VPC for the package server. This includes:

- The VPC itself, tagged with:
    vpc-name = eco-server-vpc
- A VPC Interface Endpoint to AWS Lambda.
- A Private Namespace for the VPC as a service registry.

*/
export default class VpcBaseStack extends sst.Stack {
  constructor(scope, id, props) {
    super(scope, id, props);

    const app = this.node.root;

    // VPC Network Segment.
    const vpc = new Vpc(this, "vpc", {
      maxAzs: 1,
      enableDnsSupport: false,
      enableDnsHostnames: false,
      natGateways: 0,
      subnetConfiguration: [
        //{ cidrMask: 23, name: 'Isolated', subnetType: SubnetType.ISOLATED }
        { cidrMask: 23, name: 'Public', subnetType: SubnetType.PUBLIC }
      ]
      // gatewayEndpoints: {
      //   S3: {
      //     service: GatewayVpcEndpointAwsService.S3,
      //   },
      // }
    });

    Tags.of(vpc).add('vpc-name', 'eco-server-vpc');

    new CfnOutput(this, "vpc-id", {
     value: vpc.vpcId,
     exportName: app.logicalPrefixedName("VpcId")
    });

    // Add an interface endpoint for invoking ECR and Secrets Manager
    // vpc.addInterfaceEndpoint('LambdaEndpoint', {
    //   service: InterfaceVpcEndpointAwsService.LAMBDA,
    // });

    // Add a service discovery namespace.
    const namespace = new servicediscovery.PrivateDnsNamespace(this, 'service-namespace', {
      name: 'mydomain.com',
      vpc
    });

    new CfnOutput(this, "service-namespace-id", {
     value: namespace.namespaceId,
     exportName: app.logicalPrefixedName("ServiceNamespaceId")
    });
  }
}
