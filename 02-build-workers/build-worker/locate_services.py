#!/usr/bin/env python3
import requests as req
import re
import zipfile
import json
import hashlib
import os
import subprocess
import pathlib
import shutil
import sys
import time
import logging
import boto3
from dotenv import load_dotenv, find_dotenv
from botocore.exceptions import ClientError

load_dotenv(find_dotenv())

offline_mode = os.environ.get('OFFLINE_MODE')

with open('proc_env', 'w') as proc_env:

    if offline_mode == 'true':
        # Use OFFLINE_MODE=true
        config = {
            'PACKAGE_API_ROOT': os.environ.get('PACKAGE_API_ROOT')
        }

        print(config)
    else:
        # Use OFFLINE_MODE=false
        config = {
            'AWS_CONTAINER_CREDENTIALS_RELATIVE_URI': os.environ.get('AWS_CONTAINER_CREDENTIALS_RELATIVE_URI'),
            'DISCOVERY_NAMESPACE': 'mydomain.com',
            'BUILD_API_SERVICE': 'build-api-service'
        }

        print(config)

        session = boto3.session.Session()
        print(session.get_credentials().get_frozen_credentials())


        # Find the build API service.
        print("\n=== Looking for the build API service.")
        discovery_namespace = config['DISCOVERY_NAMESPACE']
        build_api_service = config['BUILD_API_SERVICE']

        sdclient = session.client('servicediscovery')
        discovery_response = sdclient.discover_instances(
            NamespaceName=discovery_namespace,
            ServiceName=build_api_service
        )

        if not discovery_response['Instances']:
            print("Failed to discover the build API service.")
            quit()

        config['PACKAGE_API_ROOT'] = discovery_response['Instances'][0]['Attributes']['url']
        print("Got build API root URL: " + config['PACKAGE_API_ROOT'])


    proc_env.write('PACKAGE_API_ROOT=' + config['PACKAGE_API_ROOT'])
