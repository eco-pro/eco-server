import { CfnOutput, RemovalPolicy, Duration, Tags } from '@aws-cdk/core';
import { Vpc, SubnetType, GatewayVpcEndpointAwsService, InterfaceVpcEndpointAwsService } from '@aws-cdk/aws-ec2';
import * as servicediscovery from '@aws-cdk/aws-servicediscovery';
import * as sst from '@serverless-stack/resources';

/*
Set up the VPC for the package server. This includes:

- The VPC itself, tagged with:
    vpc-name = eco-server-vpc
- A Private Namespace for the VPC as a service registry.

*/
export default class VpcBaseStack extends sst.Stack {
  constructor(scope, id, props) {
    super(scope, id, props);

    const app = this.node.root;

    // VPC Network Segment.
    const vpc = new Vpc(this, "vpc", {
      maxAzs: 1,
      enableDnsSupport: true,
      enableDnsHostnames: true,
      natGateways: 0,
      subnetConfiguration: [
        { cidrMask: 23, name: 'Public', subnetType: SubnetType.PUBLIC }
      ]
    });

    Tags.of(vpc).add('vpc-name', 'eco-server-vpc');

    new CfnOutput(this, "vpc-id", {
     value: vpc.vpcId,
     exportName: app.logicalPrefixedName("VpcId")
    });

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
