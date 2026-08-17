#!/bin/bash

# Provide Region value here
REGION=${1:-'us-west-2'}
current_date=$(date +"%Y-%m-%d")
current_year=$(date +%Y)
current_month=$(date +%m)


# Define the filename with the current date
filename="-list-$current_date.txt"


REGIONS=("us-east-2" "us-west-1" "ap-south-1" "ap-northeast-3" "ap-northeast-2" "ap-southeast-1" "ap-southeast-2" "ap-northeast-1" "ca-central-1" "eu-central-1" "eu-west-1" "eu-west-2" "eu-west-3" "eu-north-1" "sa-east-1" "us-east-1" "us-west-2")





##############################################
########## fetch unused snapshot #############
##############################################

unused_snapshot() {

    echo -e "\n=============================================unused Snapshot list============================================="
    echo " "

    for region in "${REGIONS[@]}"; do
        echo "Scanning region - $region"
        
        # Get two temporary files
        ACCOUNT_ID=${2:-'self'}
        SNAP_FILE=$(mktemp)
        IMAGE_FILE=$(mktemp)

        # Get the snapshot list and the volume list
        aws --region "$region" ec2 describe-snapshots --owner-ids "$ACCOUNT_ID" --query 'Snapshots[*].[SnapshotId]' --output text > "$SNAP_FILE"

        # Check if the snapshot file is empty
        if [ -s "$SNAP_FILE" ]; then
            aws --region "$region" ec2 describe-images --owners "$ACCOUNT_ID" --filters Name=state,Values=available --query 'Images[*].BlockDeviceMappings[*].Ebs.[SnapshotId]' --output text > "$IMAGE_FILE"

            # Create an array to keep track of used snapshot IDs
            declare -A used_snapshots

            # Iterate through the image file and populate the used_snapshots array
            while read -r snapshot_id; do
                used_snapshots["$snapshot_id"]=1
            done < "$IMAGE_FILE"

            echo "All Snapshots in region $region"
            cat "$SNAP_FILE"
            echo " "
            echo "Unused Snapshots in region $region"
            # Iterate through the snapshot file and save unused snapshot IDs to the output file
            while read -r snapshot_id; do
                if [ -z "${used_snapshots[$snapshot_id]}" ]; then
                    echo "$snapshot_id"
                fi
            done < "$SNAP_FILE"
        else
            echo "No snapshots found for region $region"
        fi
        echo ""
    done
}




##############################################
############## unused_volume #################
##############################################

unused_volume() {
    echo -e "\n============================================= Volume List ============================================="
    echo " "

    for REGION in "${REGIONS[@]}"; do
        echo "Scanning region - $REGION"

        # Retrieve a list of all EBS volumes with Volume ID
        all_volumes=$(aws ec2 describe-volumes --region "$REGION" --query 'Volumes[*].VolumeId' --output text)

        if [ -z "$all_volumes" ]; then
            echo "No volumes found for region $REGION"
        else
            echo "All Volumes in region $REGION:"
            for volume_id in $all_volumes; do
                volume_name=$(aws ec2 describe-volumes --region "$REGION" --volume-ids "$volume_id" --query 'Volumes[*].Tags[?Key==`Name`].Value' --output text)
                volume_size=$(aws ec2 describe-volumes --region "$REGION" --volume-ids "$volume_id" --query 'Volumes[*].Size' --output text)

                # Replace empty volume names with "null"
                if [ -z "$volume_name" ]; then
                    volume_name="null"
                fi
                echo "Region: $REGION, Volume Name: $volume_name, Volume ID: $volume_id, Size: $volume_size GB"
            done

            echo " "
            echo "Unused Volumes in region $REGION:"
            # Retrieve a list of unused EBS volumes with Volume ID
            unused_volumes=$(aws ec2 describe-volumes --region "$REGION" --filters Name=status,Values=available --query 'Volumes[*].VolumeId' --output text)

            if [ -z "$unused_volumes" ]; then
                echo "No unused volumes found for region $REGION"
            else
                # Iterate through each unused volume and retrieve Name and Size details
                for volume_id in $unused_volumes; do
                    volume_name=$(aws ec2 describe-volumes --region "$REGION" --volume-ids "$volume_id" --query 'Volumes[*].Tags[?Key==`Name`].Value' --output text)
                    volume_size=$(aws ec2 describe-volumes --region "$REGION" --volume-ids "$volume_id" --query 'Volumes[*].Size' --output text)

                    # Replace empty volume names with "null"
                    if [ -z "$volume_name" ]; then
                        volume_name="null"
                    fi
                    echo "Region: $REGION, Volume Name: $volume_name, Volume ID: $volume_id, Size: $volume_size GB"
                done
            fi
        fi

        echo " "
    done
}




##############################################
############ unsed_api_log_group #############
##############################################

unused_apigateway_log_group() {

    echo -e "\n============================================ API Gateway Logs Groups List ============================================="
    echo " "
    
    # Function to list all API Gateway log groups
    list_apigateway_log_groups() {

        for region in "${REGIONS[@]}"; do

            echo "Scanning region: $region"
            
            # Get all API Gateway names and IDs
            api_info=$(aws apigateway get-rest-apis --region $region --query 'items[*].[name]' --output text && aws apigatewayv2 get-apis --region $region --query 'Items[*].[Name]' --output text)

            # Get all API Gateway IDs
            api_ids=$(aws apigateway get-rest-apis --region $region --query 'items[*].[id]' --output text && aws apigatewayv2 get-apis --region $region --query 'Items[*].[ApiId]' --output text | tr '\t' '\n' | sort)



            if [ -z "$api_info" ]; then
                echo "No API Gateway found in region $region."
            else
                echo "All API Gateway Names and IDs in region $region:"
                paste <(echo "$api_info") <(echo "$api_ids")
                echo " "
            fi


            # Get all API Gateway log groups
            log_groups=$(aws logs describe-log-groups --log-group-name-prefix 'API-Gateway-Execution-Logs_' --region $region --query 'logGroups[*].logGroupName' --output text | tr '\t' '\n')

            if [ -z "$log_groups" ]; then
                echo "No log groups found in region $region."
            else
                echo "All API Gateway Log Groups in region $region:"
                echo "$log_groups"
                echo " "
            fi



            # Flag to track if any unused log groups are found
            unused_found=0

            # Find unused log groups
            unused_log_groups=()
            for log_group in $log_groups; do
                log_group_id=$(echo $log_group | awk -F'_' '{print $2}' | awk -F'/' '{print $1}')
                if ! echo "$api_ids" | grep -qw "$log_group_id"; then
                    unused_log_groups+=("$log_group")
                fi
            done
            
            if [ ${#unused_log_groups[@]} -eq 0 ]; then
                echo " "
            else
                echo "Unused Apigateway log groups in region $region:"
                for log_group in "${unused_log_groups[@]}"; do
                    echo "$log_group"
                done
            fi

            echo " "
        done
    }

    # Call the function to list and identify unused log groups
    list_apigateway_log_groups
    echo " "
}



##############################################
########### unused_security_group ############
##############################################

unused_security_group() {

    echo -e "\n============================================= Unused Security Groups ============================================="
    echo " "
    
    get_unused_security_groups() {
        for region in "${REGIONS[@]}"; do
            echo "Scanning region: $region"
            
            # Initialize a list for unused security groups
            unused_groups=()
            
            # Retrieve all security groups
            security_groups=$(aws ec2 describe-security-groups --query "SecurityGroups[?GroupName!='default'].GroupId" --region $region --output text | tr '\t' '\n')
            
            if [ -z "$security_groups" ]; then
                echo "No security groups found in region $region."
            else
                echo "All Security Groups in region $region:"
                echo "$security_groups"
                echo " "
            fi
            
            # Iterate through each security group
            for group_id in $security_groups; do
                # Retrieve the ENIs associated with the security group
                enis=$(aws ec2 describe-network-interfaces --filters Name=group-id,Values="$group_id" --query "NetworkInterfaces" --region $region --output text | tr '\t' '\n')
                
                # If there are no associated ENIs, add the security group to the unused list
                if [[ -z "$enis" ]]; then
                    unused_groups+=("$group_id")
                fi
            done
            
            if [ ${#unused_groups[@]} -eq 0 ]; then
                echo "No unused security groups found in region $region."
            else
                echo "Unused Security Groups in region $region:"
                for group_id in "${unused_groups[@]}"; do
                    echo "$group_id"
                done
            fi
            
            echo " "
        done
    }
    
    # Call the function to get the unused security groups
    get_unused_security_groups
    echo " "
}




##############################################
########## unused_lambda_log_group ###########
##############################################

unused_lambda_log_group() {
    echo -e "\n============================================ Unused Lambda Logs Groups List ============================================="
    echo " "
    
    # Function to list all Lambda log groups
    list_lambda_log_groups() {
        for region in "${REGIONS[@]}"; do
            echo "Scanning region: $region"
            
            # Get all Lambda log groups
            log_groups=$(aws logs describe-log-groups --log-group-name-prefix '/aws/lambda/' --query 'logGroups[*].logGroupName' --region "$region" --output text | tr '\t' '\n')

            if [ -z "$log_groups" ]; then
                echo "No Lambda log groups found in region $region."
            else
                echo "All Lambda Log Groups in region $region:"
                echo "$log_groups"
                echo " "
            fi

            # Get all Lambda functions
            lambda_functions=$(aws lambda list-functions --query 'Functions[*].FunctionName' --region "$region" --output text | tr '\t' '\n')

            if [ -z "$lambda_functions" ]; then
                echo "No Lambda functions found in region $region."
            else
                echo "All Lambda functions in region $region:"
                echo "$lambda_functions"
                echo " "
            fi

            # Flag to track if any unused log groups are found
            unused_found=0

            # Loop through each log group and check if it's associated with a non-existent Lambda function
            unused_log_groups=()
            for log_group in $log_groups; do
                lambda_name=${log_group#/aws/lambda/}

                if ! echo "$lambda_functions" | grep -q -w "$lambda_name"; then
                    unused_log_groups+=("$log_group")
                fi
            done

            if [ ${#unused_log_groups[@]} -eq 0 ]; then
                echo "No unused Lambda log groups found in region $region."
            else
                echo "Unused Lambda Log Groups in region $region:"
                for log_group in "${unused_log_groups[@]}"; do
                    echo "$log_group"
                done
            fi

            echo " "
        done
    }

    # Call the function to list and identify unused log groups
    list_lambda_log_groups
    echo " "
}




##############################################
######### fetch unused EC2 IAM roles #########
##############################################

    
unused_ec2_iam_roles() {
    echo -e "\n=============================================unused ec2 iam roles list============================================="
    echo " "

    # Function to fetch EC2 instance details for a given region
    fetch_instances() {
        local region=$1
        aws ec2 describe-instances --region $region --query "Reservations[].Instances[].[InstanceId, Tags[?Key=='Name'].Value | [0], IamInstanceProfile.Arn]" --output text
    }

    # Function to fetch IAM roles that can be assumed by EC2 instances
    fetch_iam_roles() {
        aws iam list-roles --query "Roles[?AssumeRolePolicyDocument.Statement[?Principal.Service == 'ec2.amazonaws.com']].RoleName" --output text | tr '\t' '\n'
    }

    # Fetch IAM roles
    iam_roles=$(fetch_iam_roles)
    # Convert the list of IAM roles into an array
    iam_roles_array=($iam_roles)

    # Initialize a variable to collect used roles
    used_roles=()

    # Loop through the regions and fetch instance details
    for region in "${REGIONS[@]}"; do
        echo "Scanning region - $region"
        
        instances=$(fetch_instances $region)
        
        # Check if instances are found in the region
        if [ -z "$instances" ]; then
            echo "No instances found in region $region"
        else
            # Print the header for each region
            printf "%-20s %-30s %-50s\n" "Instance ID" "Instance Name" "Instance Role"
            
            # Loop through the instances and print the details
            while IFS=$'\t' read -r instance_id instance_name instance_profile_arn; do
                # Extract the role name from the instance profile ARN
                if [[ $instance_profile_arn =~ arn:aws:iam::[0-9]{12}:instance-profile/(.*) ]]; then
                    instance_role="${BASH_REMATCH[1]}"
                else
                    instance_role="No Role"
                fi

                # Track used roles
                if [ "$instance_role" != "No Role" ]; then
                    used_roles+=("$instance_role")
                fi

                printf "%-20s %-30s %-50s\n" "$instance_id" "$instance_name" "$instance_role"
                
            done <<< "$instances"
        fi
        echo " "
    done

    #Print all iam roles that can be assumed by ec2 instances
    echo "All EC2 Iam Roles"
    fetch_iam_roles
    echo " "
    # Check for unused roles
    echo -e "\nUnused IAM Roles:"
    for role in "${iam_roles_array[@]}"; do
        if [[ ! " ${used_roles[@]} " =~ " ${role} " ]]; then
            echo "$role"
        fi
    done
    echo " "
}




##############################################
## fetch unused Cognito Identity-pool roles ##
##############################################

unused_cognito_identity_pool_roles() {
    echo -e "\n=============================================unused Cognito Identity-pool roles============================================="
    echo " "

    # Function to get the roles attached to a specific Identity Pool
    get_roles_for_identity_pool() {
        identity_pool_id=$1
        region=$2

        # Only try to get roles if identity_pool_id is not empty
        if [ -n "$identity_pool_id" ]; then
            aws cognito-identity get-identity-pool-roles --identity-pool-id "$identity_pool_id" --region "$region" --output text 2>/dev/null |
            awk '{for (i=1; i<=NF; i++) if ($i ~ /arn:aws:iam::/) printf "%s\n", $i}' |
            awk -F/ '{print $NF}' | paste -sd "," -
        fi
    }

    # Function to get the list of all Identity Pools in a region
    fetch_identity_pools() {
        local region=$1
        aws cognito-identity list-identity-pools --region "$region" --max-results 60 --output text 2>/dev/null
    }

    # Function to fetch IAM roles that can be assumed by Cognito identity pools
    fetch_iam_roles() {
        aws iam list-roles --query "Roles[?AssumeRolePolicyDocument.Statement[?Principal.Federated=='cognito-identity.amazonaws.com']].RoleName" --output text | tr '\t' '\n'
    }

    # Fetch IAM roles
    iam_roles=$(fetch_iam_roles)
    # Convert the list of IAM roles into an array
    iam_roles_array=($iam_roles)

    # Initialize a variable to collect used roles
    used_roles=()

    # Loop through the regions and fetch identity pool details
    for REGION in "${REGIONS[@]}"; do
        echo "Checking region: $REGION"

        identity_pools=$(fetch_identity_pools "$REGION")

        # Check if identity_pools is empty
        if [ -z "$identity_pools" ]; then
            echo "No identity pools found in $REGION"
            echo " "
            continue
        fi

        # Print the header for each region
        printf "%-30s %-50s %-50s\n" "Identity Pool Name" "Identity Pool ID" "Roles"

        # Loop through each identity pool and list the attached roles
        while IFS= read -r line; do
            # Skip empty lines
            [ -z "$line" ] && continue
            
            identity_pool_id=$(echo "$line" | awk '{print $2}')
            identity_pool_name=$(echo "$line" | awk '{print $1}')

            # Skip if identity_pool_id is empty
            if [ -z "$identity_pool_id" ]; then
                continue
            fi

            roles=$(get_roles_for_identity_pool "$identity_pool_id" "$REGION")

            if [ -z "$roles" ]; then
                roles="No roles attached"
            else
                # Track used roles
                for role in $(echo $roles | tr ',' ' '); do
                    used_roles+=("$role")
                done
            fi

            printf "%-30s %-50s %-50s\n" "$identity_pool_name" "$identity_pool_id" "$roles"
        done <<< "$identity_pools"
        echo " "
    done

    #Print all iam roles that can be assumed by cognito identity pools
    echo "All Cognito Identity Pools assumable roles"
    fetch_iam_roles
    echo " "

    # Check for unused roles
    echo -e "\nUnused IAM Roles:"
    for role in "${iam_roles_array[@]}"; do
        if [[ ! " ${used_roles[@]} " =~ " ${role} " ]]; then
            echo "$role"
        fi
    done
    echo " "
}




##############################################
##### fetch unused Firehose streams roles ####
##############################################

unused_firehose_streams_roles() {
    echo -e "\n=============================================unused Firehose Streams roles============================================="
    echo " "

    # Function to list all Firehose streams and their associated IAM roles
    list_firehose_streams_and_roles() {
        local used_roles=()
        for region in "${REGIONS[@]}"; do
            echo "Checking region: $region"
            streams=$(aws firehose list-delivery-streams --region "$region" --output text --query 'DeliveryStreamNames')

            # Check if streams is empty
            if [ -z "$streams" ]; then
                echo "No Firehose streams found in $region"
                echo " "
                continue
            fi

            # Print the header for each region
            printf "%-30s %-50s\n" "Stream Name" "Role"

            for stream in $streams; do
                if [[ -n "$stream" ]]; then
                    role=$(aws firehose describe-delivery-stream --delivery-stream-name "$stream" --region "$region" --output json | awk -F'"' '/RoleARN/ {print $4; exit}' | sed 's|.*/||')
                    if [ -z "$role" ]; then
                        role="No role attached"
                    else
                        used_roles+=("$role")
                    fi
                    printf "%-30s %-50s\n" "$stream" "$role"
                fi
            done
            echo " "
        done
        echo "${used_roles[@]}" > /dev/null  # Capture roles but don't display them
    }

    # Function to list all IAM Firehose streams roles
    list_all_firehose_roles() {
        aws iam list-roles --query "Roles[?AssumeRolePolicyDocument.Statement[?Principal.Service == 'firehose.amazonaws.com']].RoleName" --output text | tr '\t' '\n'
    }

    # Function to find unused roles
    find_unused_roles() {
        local used_roles
        used_roles=$(list_firehose_streams_and_roles)
        local all_roles
        all_roles=$(list_all_firehose_roles)
        echo "Unused roles:"
        for role in $all_roles; do
            if ! echo "$used_roles" | grep -q "$role"; then
                echo "$role"
            fi
        done
    }


    list_firehose_streams_and_roles
    #Print all roles that can be assummed by Firehose streams
    echo "All Firehose streams assumable iam roles:"
    list_all_firehose_roles
    echo ""
    find_unused_roles
    echo " "
}


##############################################
######### fetch unused Lambda roles ##########
##############################################


unused_lambda_roles() {
    echo -e "\n=============================================unused Lambda IAM roles============================================="
    echo " "

    # Function to list all Lambda functions and their associated IAM roles
    list_lambda_functions_and_roles() {
        local used_roles=()
        for region in "${REGIONS[@]}"; do
            echo "Checking region: $region"
            functions=$(aws lambda list-functions --region "$region" --query "Functions[].[FunctionName, Role]" --output text)

            # Check if functions is empty
            if [ -z "$functions" ]; then
                echo "No Lambda functions found in $region"
                echo " "
                continue
            fi

            # Print the header for each region
            printf "%-30s %-50s\n" "Function Name" "Role"

            while IFS=$'\t' read -r function_name role_arn; do
                if [[ -n "$function_name" ]]; then
                    # Extract the role name from the role ARN
                    if [[ $role_arn =~ arn:aws:iam::[0-9]{12}:role/(.*) ]]; then
                        role="${BASH_REMATCH[1]}"
                    else
                        role="No role attached"
                    fi
                    
                    # Normalize role name
                    role="${role#service-role/}"
                    used_roles+=("$role")
                    
                    printf "%-30s %-50s\n" "$function_name" "$role"
                fi
            done <<< "$functions"
            echo " "
        done
        echo "${used_roles[@]}" > /dev/null  # Capture roles but don't display them
    }

    # Function to list all IAM Lambda roles
    list_all_lambda_roles() {
        aws iam list-roles --query "Roles[?AssumeRolePolicyDocument.Statement[?Principal.Service == 'lambda.amazonaws.com']].RoleName" --output text | tr '\t' '\n'
    }

    # Function to find unused roles
    find_unused_roles() {
        local used_roles
        used_roles=$(list_lambda_functions_and_roles)
        local all_roles
        all_roles=$(list_all_lambda_roles)
        echo "Unused roles:"
        for role in $all_roles; do
            normalized_role="${role#service-role/}"
            if ! echo "$used_roles" | grep -q "$normalized_role"; then
                echo "$role"
            fi
        done
    }

    list_lambda_functions_and_roles
    #Print all roles that can be assumed by lambda functions
    echo "All Lambda function assumable iam roles:"
    list_all_lambda_roles
    echo " "
    find_unused_roles
    echo " "
}




##############################################
######## fetch unused Codebuild roles ########
##############################################

unused_codebuild_roles() {
    echo -e "\n=============================================unused Codebuild roles============================================="
    echo " "

    # Function to list all CodeBuild projects and their associated IAM roles
    list_codebuild_projects_and_roles() {
        local used_roles=()
        for region in "${REGIONS[@]}"; do
            echo "Checking region: $region"
            projects=$(aws codebuild list-projects --region "$region" --query 'projects[*]' --output text)

            # Check if projects is empty
            if [ -z "$projects" ]; then
                echo "No CodeBuild projects found in $region"
                echo " "
                continue
            fi

            # Print the header for each region
            printf "%-30s %-50s\n" "Project Name" "Role"

            for project in $projects; do
                if [[ -n "$project" ]]; then
                    # Get the service role for the project
                    role_arn=$(aws codebuild batch-get-projects --names "$project" --region "$region" --query 'projects[0].serviceRole' --output text)
                    
                    # Extract role name from ARN
                    if [[ $role_arn =~ arn:aws:iam::[0-9]{12}:role/(.*) ]]; then
                        role="${BASH_REMATCH[1]}"
                    else
                        role="No role attached"
                    fi
                    
                    used_roles+=("$role")
                    printf "%-30s %-50s\n" "$project" "$role"
                fi
            done
            echo " "
        done
        echo "${used_roles[@]}" > /dev/null  # Capture roles but don't display them
    }

    # Function to list all IAM CodeBuild roles
    list_all_codebuild_roles() {
        aws iam list-roles --query "Roles[?contains(AssumeRolePolicyDocument.Statement[].Principal.Service, 'codebuild.amazonaws.com')].RoleName" --output text | tr '\t' '\n'
    }

    # Function to find unused roles
    find_unused_roles() {
        local used_roles
        used_roles=$(list_codebuild_projects_and_roles)
        local all_roles
        all_roles=$(list_all_codebuild_roles)
        echo "Unused roles:"
        for role in $all_roles; do
            if ! echo "$used_roles" | grep -q "$role"; then
                echo "$role"
            fi
        done
    }

    list_codebuild_projects_and_roles
    #Print all iam roles that can be assumed by codebuild
    echo "All codebuild assumable iam roles:"
    list_all_codebuild_roles
    echo " "
    find_unused_roles
    echo " "
}



##############################################
##### fetch unused Cloudformation roles ######
##############################################

unused_cloudformation_stack_roles() {
    echo -e "\n=============================================unused Cloudformation roles============================================="
    echo " "


    # Function to get all CloudFormation stacks (including nested stacks)
    get_all_stacks() {
        local region=$1
        aws cloudformation list-stacks --region $region --query 'StackSummaries[?StackStatus!=`DELETE_COMPLETE`].StackName' --output text
    }

    # Function to get the IAM role name associated with a stack
    get_stack_role_name() {
        local stack_name=$1
        local region=$2
        local role_arn=$(aws cloudformation describe-stacks --stack-name $stack_name --region $region --query 'Stacks[0].RoleARN' --output text)
        echo $role_arn | awk -F'/' '{print $NF}'
    }

    # Step 1: List all IAM roles that can be assumed by CloudFormation
    all_cf_roles=$(aws iam list-roles --query 'Roles[?AssumeRolePolicyDocument.Statement[?Principal.Service==`cloudformation.amazonaws.com`]].RoleName' --output text)
    cf_roles_array=($all_cf_roles)

    # Step 2: List all CloudFormation stacks and their associated roles
    used_roles=()

    for region in "${REGIONS[@]}"; do
        echo "Scanning region - $region"
        
        stacks=$(get_all_stacks $region)
        
        # Check if stacks are found in the region
        if [ -z "$stacks" ]; then
            echo "No stacks found in region $region"
        else
            # Print the header for each region with increased spacing
            printf "%-60s %-50s\n" "Stack Name" "Stack Role"
            
            for stack in $stacks; do
                role_name=$(get_stack_role_name $stack $region)
                if [ -z "$role_name" ]; then
                    role_name="No Role"
                else
                    used_roles+=("$role_name")
                fi
                
                printf "%-60s %-50s\n" "$stack" "$role_name"
            done
        fi
        echo " "
    done

    # Step 3: List all IAM roles that can be assumed by CloudFormation stacks
    echo -e "\nAll CloudFormation assumable roles:"
    for role in "${cf_roles_array[@]}"; do
        echo "$role"
    done

    # Step 4: Find unused roles
    echo -e "\nUnused CloudFormation Roles:"
    for role in "${cf_roles_array[@]}"; do
        if [[ ! " ${used_roles[@]} " =~ " ${role} " ]]; then
            echo "$role"
        fi
    done
    echo " "
}




# Call the functions
unused_snapshot >> "snapshots$filename"
unused_volume >> "volumes$filename"
unused_apigateway_log_group >> "apigateway-log-group$filename"
unused_security_group >> "security-group$filename"
unused_lambda_log_group >> "lambda-log-group$filename"
unused_ec2_iam_roles >> "ec2-iam-roles$filename"
unused_cognito_identity_pool_roles >> "cognito-identity-pool-roles$filename"
unused_firehose_streams_roles >> "firehose-streams-roles$filename"
unused_lambda_roles >> "lambda-roles$filename"
unused_codebuild_roles >> "codebuild-roles$filename"
unused_cloudformation_stack_roles >> "cloudformation-stack-roles$filename"




sleep 1
aws s3 cp . "s3://stg-bucket-logs/unused-resource-list/$current_year/$current_month/$current_date/" --recursive --exclude "*" --include "*-list-*.txt" > /dev/null 2>&1


echo -e "Hi Team,\n\nUnused Resource list has been updated in S3 bucket location: s3://stg-bucket-logs/unused-resource-list/$current_year/$current_month/$current_date/ \n\nPlease refer to detailed runbook at - https://omronhealthcare-ohi.atlassian.net/wiki/spaces/ODS/pages/2804547606/ODS-Alert-Runbook+Unused+Resource+List+Alert.\n\nSincerely,\nConnected Health R&D Team\n\nThis message is intended for designated recipients only. If you are not the authorized recipient, or you were not expecting this message, or if you have received this message in error, please delete all copies of this message. Any unauthorized use or distribution of this message is prohibited." | mail -s "US-STG-Alert : Unused Resource List Alert" awsalert.staging@ohiomron.com -r awsalert.staging@ohiomron.com

rm *$filename