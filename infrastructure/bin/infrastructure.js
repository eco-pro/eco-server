#!/usr/bin/env node

const cdk = require('@aws-cdk/core');
const { InfrastructureStack } = require('../lib/eco-server-stack');

const app = new cdk.App();
new InfrastructureStack(app, 'eco-server-stack');
