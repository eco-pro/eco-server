import {
  CfnOutput
} from "@aws-cdk/core";
import * as dynamodb from "@aws-cdk/aws-dynamodb";
import * as sst from "@serverless-stack/resources";

export default class PackageDBStack extends sst.Stack {
  constructor(scope, id, props) {
    super(scope, id, props);

    const app = this.node.root;

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

    buildStatusTable.addGlobalSecondaryIndex({
      indexName: "eco-buildstatus-byfqpackage",
      projectType: dynamodb.ProjectionType.ALL,
      partitionKey: {
        name: "fqPacakge",
        type: dynamodb.AttributeType.STRING
      }
    });

    const markersTable = new dynamodb.Table(this, "eco-markers", {
      billingMode: dynamodb.BillingMode.PAY_PER_REQUEST,
      partitionKey: {
        name: "source",
        type: dynamodb.AttributeType.STRING
      }
    });

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
