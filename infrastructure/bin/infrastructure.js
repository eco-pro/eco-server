#!/usr/bin/env node

const cdk = require('@aws-cdk/core');
const { InfrastructureStack } = require('../lib/infrastructure-stack');

const app = new cdk.App();
new InfrastructureStack(app, 'InfrastructureStack');
