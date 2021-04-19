import { CfnOutput, RemovalPolicy, Duration, Tags } from '@aws-cdk/core';
import { Vpc, SubnetType, GatewayVpcEndpointAwsService, InterfaceVpcEndpointAwsService } from '@aws-cdk/aws-ec2';
import * as servicediscovery from '@aws-cdk/aws-servicediscovery';
import * as sst from '@serverless-stack/resources';

/*
Set up the VPC for the package server. This includes:

- The VPC itself, tagged with:
    vpc-name = eco-server-vpc
- A VPC Interface Endpoint (a Private Link to API gateway).
- A Private DNS Namespace for the VPC as a service registry.

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
        { cidrMask: 23, name: 'Isolated', subnetType: SubnetType.ISOLATED }
      ],
      gatewayEndpoints: {
        S3: {
          service: GatewayVpcEndpointAwsService.S3,
        },
      }
    });

    Tags.of(vpc).add('vpc-name', 'eco-server-vpc');

    new CfnOutput(this, "vpc-id", {
     value: vpc.vpcId,
     exportName: app.logicalPrefixedName("VpcId")
    });

    // Add an interface endpoint
    vpc.addInterfaceEndpoint('LambdaEndpoint', {
      service: InterfaceVpcEndpointAwsService.LAMBDA,
    });

    // const vpcEndpoint = new ec2.InterfaceVpcEndpoint(this, 'vpc-endpoint', {
    //   vpc,
    //   service: {
    //     name: 'com.amazonaws.eu-west-2.execute-api',
    //     port: 443
    //   },
    //   privateDnsEnabled: true
    // })
    //
    // new CfnOutput(this, "vpc-endpoint-id", {
    //  value: vpcEndpoint.vpcEndpointId,
    //  exportName: app.logicalPrefixedName("VpcEndpointId")
    // });

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
