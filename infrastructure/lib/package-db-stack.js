import {
  CfnOutput
} from "@aws-cdk/core";
import * as dynamodb from "@aws-cdk/aws-dynamodb";
import * as sst from "@serverless-stack/resources";

export default class PackageDBStack extends sst.Stack {
  constructor(scope, id, props) {
    super(scope, id, props);

    const app = this.node.root;

    // BuildStatusTable:
    //   Type: 'AWS::DynamoDB::Table'
    //   DeletionPolicy: Delete
    //   Properties:
    //     AttributeDefinitions:
    //       - AttributeName: label
    //         AttributeType: S
    //       - AttributeName: seq
    //         AttributeType: N
    //       - AttributeName: fqPackage
    //         AttributeType: S
    //     KeySchema:
    //       - AttributeName: label
    //         KeyType: HASH
    //       - AttributeName: seq
    //         KeyType: RANGE
    //     ProvisionedThroughput:
    //       ReadCapacityUnits: 1
    //       WriteCapacityUnits: 1
    //     TableName: ${self:provider.environment.DYNAMODB_NAMESPACE}-eco-buildstatus
    //     GlobalSecondaryIndexes:
    //       - IndexName: ${self:provider.environment.DYNAMODB_NAMESPACE}-eco-buildstatus-byfqpackage
    //         KeySchema:
    //           - AttributeName: fqPackage
    //             KeyType: HASH
    //         Projection:
    //           ProjectionType: ALL
    //         ProvisionedThroughput:
    //           ReadCapacityUnits: 1
    //           WriteCapacityUnits: 1
    const buildStatusTable = new dynamodb.Table(this, "eco-buildstatus", {
      billingMode: dynamodb.BillingMode.PAY_PER_REQUEST,
      partitionKey: {
        name: "label",
        type: dynamodb.AttributeType.STRING
      },
      sortKey: {
        name: "seq",
        type: dynamodb.AttributeType.NUMBER
      }
    });

    //
    // MarkersTable:
    //   Type: 'AWS::DynamoDB::Table'
    //   DeletionPolicy: Delete
    //   Properties:
    //     AttributeDefinitions:
    //       - AttributeName: source
    //         AttributeType: S
    //     KeySchema:
    //       - AttributeName: source
    //         KeyType: HASH
    //     ProvisionedThroughput:
    //       ReadCapacityUnits: 1
    //       WriteCapacityUnits: 1
    //     TableName: ${self:provider.environment.DYNAMODB_NAMESPACE}-eco-markers
    const markersTable = new dynamodb.Table(this, "eco-markers", {
      billingMode: dynamodb.BillingMode.PAY_PER_REQUEST,
      partitionKey: {
        name: "source",
        type: dynamodb.AttributeType.STRING
      }
    });

    // RootSiteImportsTable:
    //   Type: 'AWS::DynamoDB::Table'
    //   DeletionPolicy: Delete
    //   Properties:
    //     AttributeDefinitions:
    //       - AttributeName: seq
    //         AttributeType: N
    //     KeySchema:
    //       - AttributeName: seq
    //         KeyType: HASH
    //     ProvisionedThroughput:
    //       ReadCapacityUnits: 1
    //       WriteCapacityUnits: 1
    //     TableName: ${self:provider.environment.DYNAMODB_NAMESPACE}-eco-rootsiteimports
    const rootSiteImportsTable = new dynamodb.Table(this, "eco-rootsiteimports", {
      billingMode: dynamodb.BillingMode.PAY_PER_REQUEST,
      partitionKey: {
        name: "seq",
        type: dynamodb.AttributeType.NUMBER
      }
    });

    // Output values
    // new CfnOutput(this, "TableName", {
    //   value: table.tableName,
    //   exportName: app.logicalPrefixedName("TableName"),
    // });
    // new CfnOutput(this, "TableArn", {
    //   value: table.tableArn,
    //   exportName: app.logicalPrefixedName("TableArn"),
    // });
  }
}
