'use strict';

class Cloudmap {
  constructor(serverless, options) {
    this.serverless = serverless;
    this.options = options;

    this.commands = {
      deploy: {
        lifecycleEvents: ['resources', 'functions'],
      },
    };

    this.hooks = {
      'package:initialize': this.generateCloudformation.bind(this),
    };
  }

  generateCloudformation() {
    const {
      cloudmap
    } = this.serverless.service.custom;
    const rsrc = this.serverless.service.provider.compiledCloudFormationTemplate.Resources;
    const {
      services
    } = cloudmap;
    services.forEach((service) => {
      rsrc[service.cfname] = {
        'Type': 'AWS::ServiceDiscovery::Service',
        'Properties': {
          'Description': service.description,
          'Name': service.name,
          'NamespaceId': service.namespace,
          'DnsConfig': {
            'DnsRecords': [ { 'TTL' : 100, 'Type' : 'CNAME' } ],
            'RoutingPolicy': 'WEIGHTED'
          }
        },
      };
      service.instances.forEach((instance) => {
        rsrc[instance.cfname] = {
          'Type': "AWS::ServiceDiscovery::Instance",
          'Properties': {
            'InstanceAttributes': {
              'arn': instance.arn,
              'handler': instance.name,
              'url': instance.url,
              'type': 'function',
              'AWS_INSTANCE_CNAME': instance.cname,
              ...instance.config,
            },
            'InstanceId': instance.name,
            'ServiceId': {
              'Ref': service.cfname,
            }
          },
        };
      });
    });

    this.serverless.service.provider.compiledCloudFormationTemplate.Resources = rsrc;
  };
}

module.exports = Cloudmap;
