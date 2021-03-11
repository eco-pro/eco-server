import { Api, Stack, Table, TableFieldType } from "@serverless-stack/resources";
import { CfnOutput, RemovalPolicy } from "@aws-cdk/core";
import * as s3 from "@aws-cdk/aws-s3";
import * as dynamodb from "@aws-cdk/aws-dynamodb";

export default class PackageDBStack extends Stack {
  constructor(scope, id, props) {
    super(scope, id, props);

    const app = this.node.root;

    // Buckets for Build Artifacts.
    const packagesBucket = new s3.Bucket(this, 'elm-packages', {
      versioned: false,
      autoDeleteObjects: true,
      removalPolicy: RemovalPolicy.DESTROY
    });

    new CfnOutput(this, "elm-packages-bucket", {
      value: packagesBucket.bucketName
    });

    const buildLogsBucket = new s3.Bucket(this, 'elm-build-logs', {
      versioned: false,
      autoDeleteObjects: true,
      removalPolicy: RemovalPolicy.DESTROY
    });

    new CfnOutput(this, "elm-build-logs-bucket", {
      value: buildLogsBucket.bucketName
    });

    // DynamoDB tables for build metadata.
    const buildStatusTable = new dynamodb.Table(this, "build-status", {
      billingMode: dynamodb.BillingMode.PAY_PER_REQUEST,
      partitionKey: { name: "label", type: dynamodb.AttributeType.STRING },
      sortKey: { name: "seq", type: dynamodb.AttributeType.NUMBER },
      removalPolicy: RemovalPolicy.DESTROY
    });

    buildStatusTable.addGlobalSecondaryIndex({
      indexName: "buildstatus-byfqpackage",
      projectType: dynamodb.ProjectionType.ALL,
      partitionKey: { name: "fqPacakge", type: dynamodb.AttributeType.STRING }
    });

    new CfnOutput(this, "build-status-table", {
     value: buildStatusTable.tableName,
     exportName: app.logicalPrefixedName("build-status-arn"),
    });

    const markersTable = new dynamodb.Table(this, "markers", {
      billingMode: dynamodb.BillingMode.PAY_PER_REQUEST,
      partitionKey: { name: "source", type: dynamodb.AttributeType.STRING },
      removalPolicy: RemovalPolicy.DESTROY
    });

    new CfnOutput(this, "markers-table", {
     value: markersTable.tableName,
     exportName: app.logicalPrefixedName("markers-arn"),
    });

    const rootSiteImportsTable = new dynamodb.Table(this, "rootsiteimports", {
      billingMode: dynamodb.BillingMode.PAY_PER_REQUEST,
      partitionKey: { name: "seq", type: dynamodb.AttributeType.NUMBER },
      removalPolicy: RemovalPolicy.DESTROY
    });

    new CfnOutput(this, "rootsiteimports-table", {
     value: rootSiteImportsTable.tableName,
     exportName: app.logicalPrefixedName("rootsiteimports-arn"),
    });
  }
}
