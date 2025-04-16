application_name = "cloudtrail-alerting"
iam_events = [
  "DeleteUser",
  "CreateUser",
  "CreateGroup",
  "DeleteGroup",
  "CreateAccessKey",
  "DeleteAccessKey",
  "DeleteVirtualMFADevice",
  "DeactivateMFADevice"
]
sns_endpoint = "xxxxxxxxxxx@example.com"