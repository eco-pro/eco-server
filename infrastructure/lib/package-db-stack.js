import { Api, Stack, Table } from "@serverless-stack/resources";
import { CfnOutput } from "@aws-cdk/core";

export default class PackageDBStack extends Stack {
  constructor(scope, id, props) {
    super(scope, id, props);

    const app = this.node.root;

    // Buckets for Build Artifacts.
    new s3.Bucket(this, 'elm-packages', {
      versioned: false
    });

    new s3.Bucket(this, 'elm-build-logs', {
      versioned: false
    });

    // DynamoDB tables for build metadata.
    const buildStatusTable = new Table(this, "buildstatus", {
      fields: {
        label: TableFieldType.STRING,
        seq: TableFieldType.NUMBER,
        fqPackage: TableFieldType.STRING,
      },
      primaryIndex: { partitionKey: "label", sortKey: "seq" },
      secondaryIndexes: {
        byfqpackage: { partitionKey: "fqPackage" },
      },
    });

    const markersTable = new Table(this, "markers", {
      fields: {
        source: TableFieldType.STRING
      },
      primaryIndex: { partitionKey: "source" }
    });

    const rootSiteImportsTable = new Table(this, "rootsiteimports", {
      fields: {
        seq: TableFieldType.NUMBER
      },
      primaryIndex: { partitionKey: "seq" }
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
