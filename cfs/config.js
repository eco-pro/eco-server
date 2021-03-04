'use strict';

module.exports = {
  config: {
    PROJECT: 'Eco Package Server',
    PROJECT_VERSION: '0.0.1',
    PROJECT_PREFIX: 'eco-server-',
    SERVICE_CODE: 'eco-server',
    API_PACKAGE_VERSION: '0.0.1',

    API: {
      DIST_DIR: '../api/lambda/dist',
      PACKAGE_DIR: '../dist/api'
    },

    STACK: {
      CORE: {
        name: 'core',
        script: 'templates/core-cf.yaml'
      }
    },

    VPC: {
      AZS: {
        "eu-west-2": {
          AZ1: 'eu-west-2a',
          AZ2: 'eu-west-2b',
          AZ3: 'eu-west-2c'
        }
      }
    },
  },

  schema: {
    REPOSITORY: {
      description: 'Docker Repository',
      argName: 'repo'
    },
    JOB_NAME: {
      description: 'Job Name',
      argName: 'job'
    },
    JOB_IMAGE: {
      description: 'Job Docker Image',
      argName: 'image'
    },
    JOB_SCHEDULE: {
      description: 'Job Schedule (minutes)',
      argName: 'schedule'
    }
  }
};
