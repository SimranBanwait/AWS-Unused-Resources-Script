#!/bin/bash

# Define variables
FILE="/home/ubuntu/logs/unused-resource-script/"
EMAIL_SUBJECT="US-STG-Alert - Unused Resource Cron Failed Alert"
EMAIL_RECIPIENT="awsalert.staging@ohiomron.com"
EMAIL_SENDER="awsalert.staging@ohiomron.com"

# Compose the email content
EMAIL_BODY=$(cat <<EOF
Hi Team,

The Unused Resource Script has encountered an error and failed to execute successfully. Please review the error logs for further details.

Error Log Location:
$FILE

Please refer to detailed runbook at - https://omronhealthcare-ohi.atlassian.net/wiki/spaces/ODS/pages/3161587917/ODS-Alert-Runbook+REGION+-+ENV+-Unused-Resource-Cron+-+Failed

Sincerely,
Connected Health R&D Team

This message is intended for designated recipients only. If you are not the authorized recipient, or you were not expecting this message, or if you have received this message in error, please delete all copies of this message. Any unauthorized use or distribution of this message is prohibited.
EOF
)

# Send the email
echo -e "$EMAIL_BODY" | mail -s "$EMAIL_SUBJECT" "$EMAIL_RECIPIENT" -r "$EMAIL_SENDER"

