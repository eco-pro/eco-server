import { Api, Stack, Table, TableFieldType } from "@serverless-stack/resources";
import { CfnOutput } from "@aws-cdk/core";
import * as s3 from "@aws-cdk/aws-s3";
import * as dynamodb from "@aws-cdk/aws-dynamodb";

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
        byfqpackage: {
          partitionKey: "fqPackage",
          indexProps: {
            projectionType: dynamodb.ProjectionType.ALL
          }
        },
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
    // new CfnOutput(this, "buildstatusArn", {
    //   value: buildStatusTable.tableName,
    //   exportName: app.logicalPrefixedName("buildstatusArn"),
    // });
    // new CfnOutput(this, "markersArn", {
    //   value: markersTable.markers,
    //   exportName: app.logicalPrefixedName("markersArn"),
    // });

    //
    // new CfnOutput(this, "rootsiteimportsArn", {
    //   value: rootSiteImportsTable.tableName,
    //   exportName: app.logicalPrefixedName("rootsiteimports"),
    // });
  }
}
