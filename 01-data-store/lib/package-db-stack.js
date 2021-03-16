import { Api, Stack, Table, TableFieldType } from "@serverless-stack/resources";
import { CfnOutput, RemovalPolicy } from "@aws-cdk/core";
import * as s3 from "@aws-cdk/aws-s3";
import * as dynamodb from "@aws-cdk/aws-dynamodb";
import { Effect, PolicyStatement } from '@aws-cdk/aws-iam';

export default class PackageDBStack extends Stack {
  constructor(scope, id, props) {
    super(scope, id, props);

    const app = this.node.root;

    // Buckets for Build Artifacts.
    const packagesBucket = new s3.Bucket(this, 'elm-packages', {
      versioned: false,
      autoDeleteObjects: true,
      removalPolicy: RemovalPolicy.DESTROY,
      publicReadAccess: true
    });

    new CfnOutput(this, "elm-packages-bucket-name", {
     value: packagesBucket.bucketName,
     exportName: app.logicalPrefixedName("ElmPackageBucketName")
    });

    new CfnOutput(this, "elm-packages-bucket-arn", {
     value: packagesBucket.bucketArn,
     exportName: app.logicalPrefixedName("ElmPackageBucketArn")
    });

    const buildLogsBucket = new s3.Bucket(this, 'elm-build-logs', {
      versioned: false,
      autoDeleteObjects: true,
      removalPolicy: RemovalPolicy.DESTROY,
      publicReadAccess: true
    });

    // buildLogsBucket.addToResourcePolicy(new PolicyStatement({
    //   effect: Effect.ALLOW,
    //   actions: ["s3:*"],
    //   resources: [
    //     buildLogsBucket.bucketArn,
    //     buildLogsBucket.bucketArn + "/*"
    //   ],
    //   principal: ["*"]// -- Seems to need a principal
    // }));

    new CfnOutput(this, "elm-build-logs-bucket-name", {
     value: buildLogsBucket.bucketName,
     exportName: app.logicalPrefixedName("ElmBuildLogsBucketName")
    });

    new CfnOutput(this, "elm-build-logs-bucket-arn", {
     value: buildLogsBucket.bucketArn,
     exportName: app.logicalPrefixedName("ElmBuildLogsBucketArn")
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
      partitionKey: { name: "fqPackage", type: dynamodb.AttributeType.STRING }
    });

    new CfnOutput(this, "build-status-table-name", {
     value: buildStatusTable.tableName,
     exportName: app.logicalPrefixedName("BuildStatusTableName")
    });

    new CfnOutput(this, "build-status-table-arn", {
     value: buildStatusTable.tableArn,
     exportName: app.logicalPrefixedName("BuildStatusTableArn")
    });

    new CfnOutput(this, "build-status-by-fqpackage-index", {
     value: "buildstatus-byfqpackage",
     exportName: app.logicalPrefixedName("BuildStatusByFQPackageIndex")
    });

    const markersTable = new dynamodb.Table(this, "markers", {
      billingMode: dynamodb.BillingMode.PAY_PER_REQUEST,
      partitionKey: { name: "source", type: dynamodb.AttributeType.STRING },
      removalPolicy: RemovalPolicy.DESTROY
    });

    new CfnOutput(this, "markers-table-name", {
     value: markersTable.tableName,
     exportName: app.logicalPrefixedName("MarkersTableName")
    });

    new CfnOutput(this, "markers-table-arn", {
     value: markersTable.tableArn,
     exportName: app.logicalPrefixedName("MarkersTableArn")
    });

    const rootSiteImportsTable = new dynamodb.Table(this, "rootsiteimports", {
      billingMode: dynamodb.BillingMode.PAY_PER_REQUEST,
      partitionKey: { name: "seq", type: dynamodb.AttributeType.NUMBER },
      removalPolicy: RemovalPolicy.DESTROY
    });

    new CfnOutput(this, "rootsiteimports-table-name", {
     value: rootSiteImportsTable.tableName,
     exportName: app.logicalPrefixedName("RootSiteImportsTableName")
    });

    new CfnOutput(this, "rootsiteimports-table-arn", {
     value: rootSiteImportsTable.tableArn,
     exportName: app.logicalPrefixedName("RootSiteImportsTableArn")
    });
  }
}
