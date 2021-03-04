'use strict';

module.exports = {
  config: {
    ACS_IDENTITY_ACCOUNT_ID: '822179100693',
    ACS_IDENTITY_USER_POOL : 'cognito-idp.us-east-1.amazonaws.com/us-east-1_rHpIZR44Q',

    PROJECT:         'NumElm Spike',
    PROJECT_VERSION: '0.0.1',
    PROJECT_PREFIX:  'numelm-spike-',
    SERVICE_CODE:    'numelm-spike',
    API_PACKAGE_VERSION: '0.0.1',

    API: {
      DIST_DIR:  '../api/lambda/dist',
      PACKAGE_DIR: '../dist/api'
    },

    STACK: {
      CORE:    { name: 'core',      script: 'templates/core-cf.yaml' }
    },

    VPC: {
      AZS: {
        "us-east-1" : {
          AZ1: 'us-east-1a',
          AZ2: 'us-east-1c',
          AZ3: 'us-east-1e'
        }
      }
    },

    EC2: {
      AMI:  'ami-c58c1dd3',
      TYPE: 't2.micro'
    },

    ECS: {
      AMI:  'ami-9eb4b1e5',
      TYPE: 't2.micro'
    },

    LAMBDA: {
      CLIENT_CONTEXT: 'eyJjbGllbnQiOiJhd3MubGFtYmRhLmludm9rZSJ9=' // base64 enc: {"client":"aws.lambda.invoke"}
    },

    WEB: {
      S3_BUCKET: {
        prod: '_PROJECT_CODE.connect.analog.com',
        dev:  '_PROJECT_CODE.connect-dev.analog.com'
      },
      DIST_DIR: '../app/web/dist'
    }
  },

  schema: {
    REPOSITORY:   { description: 'Docker Repository',      argName: 'repo'    },
    JOB_NAME:     { description: 'Job Name',               argName: 'job'     },
    JOB_IMAGE:    { description: 'Job Docker Image',       argName: 'image'   },
    JOB_SCHEDULE: { description: 'Job Schedule (minutes)', argName: 'schedule'}
  }
};
