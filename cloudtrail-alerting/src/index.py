import json
import os
import boto3

client = boto3.client('sns')
snsTopicArn = os.environ.get("SNS_TOPIC_ARN")

def lambda_handler(event, context):
    extracted = extract_event_details(event)
    subject = build_subject(extracted)

    response = client.publish(
        TopicArn=snsTopicArn,
        Subject=subject,
        Message=json.dumps({'default': json.dumps(event, indent=2)}),
        MessageStructure='json'
        )
    
    print("Message published to SNS")
    return response

def extract_event_details(event):
    details = {
        "accountId": event.get("account"),
        "userIdentityType": event.get("detail", {}).get("userIdentity", {}).get("type"),
        "eventName": event.get("detail", {}).get("eventName")
    }

    return details

def build_subject(extracted):
    user_type = extracted["userIdentityType"]
    event_name = extracted["eventName"]
    account_id = extracted["accountId"]

    if user_type == "Root":
        subject = f"Root API call detected: {event_name} in account {account_id}"
    else:
        subject = f"Alert: IAM API call '{event_name}' detected in account {account_id}"

    return subject