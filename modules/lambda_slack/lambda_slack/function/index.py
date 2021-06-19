from __future__ import print_function

import boto3
import json
import logging
import os

from base64 import b64decode
from urllib.request import Request, urlopen
from urllib.error import URLError, HTTPError

# # value of the CiphertextBlob key in output of $ aws kms encrypt --key-id alias/<KMS key name> --plaintext "<SLACK_HOOK_URL>"
# ENCRYPTED_HOOK_URL = "CiC9..."
# HOOK_URL = "https://" + boto3.client('kms').decrypt(CiphertextBlob=b64decode(ENCRYPTED_HOOK_URL))['Plaintext']

# HOOK_URL = "https://" + boto3.client('kms').decrypt(CiphertextBlob=b64decode(ENCRYPTED_HOOK_URL))['Plaintext']

logger = logging.getLogger()
logger.setLevel(logging.INFO)
HOOK_URL = region = os.environ['HOOK_URL']
SLACK_CHANNEL = "wordpress-alerts"

def handler(event, context):
    logger.info("Event: " + str(event))
    # message = json.loads(str(event['Records'][0]['Sns']))
    # logger.info("Message: " + str(message))

    if event["detail-type"] == "ECS Deployment State Change":
        event_type = event["detail"]["eventType"]
        event_name = event["detail"]["eventName"]
        message_text = "ECS Deployment Change: " + event_type + ": " + event_name
    elif event["detail-type"] == "ECS Service Action":
        event_type = event["detail"]["eventType"]
        event_name = event["detail"]["eventName"]
        message_text = "ECS Service Status Change: " + event_type + ": " + event_name
    elif event["detail-type"] == "ECS Task State Change":
        event_id = event["detail"]["taskArn"]
        desired_status = event_type = event["detail"]["desiredStatus"]
        launch_type = event_type = event["detail"]["launchType"]
        last_status = event_type = event["detail"]["lastStatus"]
        message_text = "ECS Task Status Change: " + launch_type + ":" + event_id + ": Desired was " + desired_status + " and last was " + last_status
    elif event["detail-type"] == "ECS Container Instance State Change":
        event_id = event["detail"]["containerInstanceArn"]
        event_status = event_id = event["detail"]["status"]
        message_text = "Container Instance State Change: " + event_id + ":" + event_status
    elif event["detail-type"] == "RDS DB Cluster Event":
        event_id = event["detail"]["SourceIdentifier"]
        event_message = event_id = event["detail"]["Message"]
        message_text = "RDS Cluster State Change: " + event_id + ":" + event_message

    else:
        raise ValueError("detail-type for event is not a supported type. Exiting without notifying event.")


    slack_message = {
        'channel': SLACK_CHANNEL,
        'text': message_text
    }

    req = Request(HOOK_URL, json.dumps(slack_message).encode('utf-8'))
    try:
        response = urlopen(req)
        response.read()
        logger.info("Message posted to %s", slack_message['channel'])
    except HTTPError as e:
        logger.error("Request failed: %d %s", e.code, e.reason)
    except URLError as e:
        logger.error("Server connection failed: %s", e.reason)
