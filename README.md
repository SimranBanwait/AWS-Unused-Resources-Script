# AWS Unused Resources Script

This script (`usstg-unused-resource-script.sh`) is designed to identify unused AWS resources across multiple regions. It helps in maintaining a clean AWS environment and potentially reducing costs by identifying resources that are no longer in use.

## Features

The script scans for the following unused AWS resources across a list of predefined regions:

- **EBS Snapshots:** Snapshots not associated with any AMIs.
- **EBS Volumes:** Volumes with a status of `available` (not attached to any instance).
- **API Gateway Log Groups:** CloudWatch Log Groups for API Gateway that are not associated with any active API.
- **Security Groups:** Security Groups not associated with any Network Interface (ENI).
- **Lambda Log Groups:** CloudWatch Log Groups for Lambda functions that no longer exist.
- **IAM Roles:** Unused IAM roles associated with:
    - EC2 Instances
    - Cognito Identity Pools
    - Kinesis Firehose Streams
    - Lambda Functions
    - CodeBuild Projects
    - CloudFormation Stacks

## Prerequisites

- **AWS CLI:** Must be installed and configured with appropriate credentials.
- **Permissions:** The AWS credentials used must have read-only access to the resources being scanned (EC2, API Gateway, CloudWatch Logs, IAM, Lambda, Cognito, Firehose, CodeBuild, CloudFormation) and write access to the target S3 bucket.
- **Mail Utilities:** The `mail` command must be configured on the system to send email notifications.
- **Bash:** The script is written for the Bash shell.

## Usage

1.  **Make the script executable:**
    ```bash
    chmod +x usstg-unused-resource-script.sh
    ```

2.  **Run the script:**
    ```bash
    ./usstg-unused-resource-script.sh [REGION]
    ```
    - `[REGION]` (Optional): The primary region (defaults to `us-west-2` if not provided). Note that the script internally iterates through a fixed list of regions for most resource checks.

## Scanned Regions

The script currently scans the following regions:
`us-east-2`, `us-west-1`, `ap-south-1`, `ap-northeast-3`, `ap-northeast-2`, `ap-southeast-1`, `ap-southeast-2`, `ap-northeast-1`, `ca-central-1`, `eu-central-1`, `eu-west-1`, `eu-west-2`, `eu-west-3`, `eu-north-1`, `sa-east-1`, `us-east-1`, `us-west-2`.

## Output and Notifications

- **Local Files:** The script generates temporary text files for each resource type (e.g., `snapshots-list-YYYY-MM-DD.txt`).
- **S3 Upload:** All generated reports are uploaded to the following S3 bucket path:
  `s3://stg-bucket-logs/unused-resource-list/YYYY/MM/DD/`
- **Email Notification:** An email is sent to `awsalert.staging@ohiomron.com` upon completion, notifying the team that the list has been updated.
- **Cleanup:** Temporary local files are deleted after the S3 upload.

## Configuration

- **REGIONS:** The list of regions to scan can be modified in the `REGIONS` array at the top of the script.
- **S3 Bucket:** The target S3 bucket can be changed in the `aws s3 cp` command at the end of the script.
- **Email:** The recipient and sender email addresses can be updated in the `mail` command at the end of the script.
