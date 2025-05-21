#!/bin/bash

# Default parameters
TARGET_ENV=""
ACTION=""
# Try to get the AWS region from AWS CLI config, or use a default if not found
AWS_REGION=$(aws configure get region)
if [[ -z "$AWS_REGION" ]]; then
    # Check if region is set in AWS_REGION environment variable
    if [[ -n "$AWS_REGION" ]]; then
        echo "Using AWS region from environment variable: $AWS_REGION"
    else
        # Set a default region
        AWS_REGION="us-west-2"
        echo "AWS region not found in configuration. Using default region: $AWS_REGION"
    fi
fi

CURRENT_DATE="250520"  # MMDDYY format

# Function to display usage information
function display_usage {
    echo "Usage: $0 [OPTIONS]"
    echo "Options:"
    echo "  --target-env ENVIRONMENT  Specify target environment (e.g., cfndev, sandbox)"
    echo "  --action ACTION           Specify action to perform: 'up' or 'destroy'"
    echo "  -h, --help                Display this help message"
    exit 1
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --target-env)
            if [[ -n "$2" && "$2" != --* ]]; then
                export TARGET_ENV="$2"
                shift 2
            else
                echo "Error: --target-env requires an argument"
                display_usage
            fi
            ;;
        --action)
            if [[ -n "$2" && "$2" != --* ]]; then
                if [[ "$2" == "up" || "$2" == "destroy" ]]; then
                    ACTION="$2"
                    shift 2
                else
                    echo "Error: --action must be 'up' or 'destroy'"
                    display_usage
                fi
            else
                echo "Error: --action requires an argument"
                display_usage
            fi
            ;;
        -h|--help)
            display_usage
            ;;
        *)
            echo "Unknown option: $1"
            display_usage
            ;;
    esac
done

# Check that required arguments are provided
if [[ -z "$TARGET_ENV" ]]; then
    echo "Error: --target-env is required"
    display_usage
fi

if [[ -z "$ACTION" ]]; then
    echo "Error: --action is required"
    display_usage
fi

# Announce the operation with appropriate terminology
if [[ "$ACTION" == "up" ]]; then
    echo "Deploying infrastructure to $TARGET_ENV environment"
else
    echo "Destroying infrastructure in $TARGET_ENV environment"
fi

# Set and export AWS profile and region
export AWS_PROFILE="avive-$TARGET_ENV-k8s"
export AWS_DEFAULT_REGION="$AWS_REGION"
echo "Using AWS Profile: $AWS_PROFILE, Region: $AWS_REGION"

# Read the configuration file
CONFIG_FILE="$(dirname "$0")/deploy-iac.config"
if [[ -f "$CONFIG_FILE" ]]; then
    echo "Reading configuration from $CONFIG_FILE"
    source "$CONFIG_FILE"
    
    # Loop through each folder in the folder_order array
    echo "Processing folders in the following order:"
    for folder in "${folder_order[@]}"; do
        echo "- $folder"
    done
else
    echo "Warning: Configuration file $CONFIG_FILE not found. Using default configuration."
    # Default to just the single pulumi project if no config file
    folder_order=("pulumi-proj-s3-basic")
fi

# Check for KMS key and create if it doesn't exist
KMS_ALIAS_NAME="alias/test-pulumi-$TARGET_ENV"
echo "Checking for KMS key with alias: $KMS_ALIAS_NAME"

if aws kms describe-key --key-id "$KMS_ALIAS_NAME" --region "$AWS_REGION" 2>/dev/null; then
    echo "KMS key with alias $KMS_ALIAS_NAME already exists."
else
    echo "Creating new KMS key with alias $KMS_ALIAS_NAME..."
    # Create a new KMS key with the specified configuration
    KMS_KEY_ID=$(aws kms create-key \
        --description "Pulumi KMS key for $TARGET_ENV environment" \
        --key-usage "ENCRYPT_DECRYPT" \
        --key-spec "SYMMETRIC_DEFAULT" \
        --origin "AWS_KMS" \
        --region "$AWS_REGION" \
        --query 'KeyMetadata.KeyId' \
        --output text)
    
    # Create alias for the key
    aws kms create-alias \
        --alias-name "$KMS_ALIAS_NAME" \
        --target-key-id "$KMS_KEY_ID" \
        --region "$AWS_REGION"
    
    echo "KMS key created with ID: $KMS_KEY_ID and alias: $KMS_ALIAS_NAME"
fi

# Check for S3 bucket and create if it doesn't exist
S3_BUCKET_NAME="pulumi-test-$TARGET_ENV-$CURRENT_DATE"
echo "Checking for S3 bucket: $S3_BUCKET_NAME"

if aws s3api head-bucket --bucket "$S3_BUCKET_NAME" 2>/dev/null; then
    echo "S3 bucket $S3_BUCKET_NAME already exists."
else
    echo "Creating new S3 bucket $S3_BUCKET_NAME..."
    aws s3api create-bucket \
        --bucket "$S3_BUCKET_NAME" \
        --region "$AWS_REGION" \
        --create-bucket-configuration LocationConstraint="$AWS_REGION"
    
    # Enable versioning
    aws s3api put-bucket-versioning \
        --bucket "$S3_BUCKET_NAME" \
        --versioning-configuration Status=Enabled
    
    echo "S3 bucket $S3_BUCKET_NAME created successfully with versioning enabled."
fi

# Process each folder in the folder_order array
# Store the original script directory once
ORIGINAL_SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

for folder in "${folder_order[@]}"; do
    echo "===================================================="
    echo "Processing folder: $folder"
    
    # Change to the project directory
    # Use original script directory for each project to ensure correct path
    project_dir="$ORIGINAL_SCRIPT_DIR/$folder"
    if [[ ! -d "$project_dir" ]]; then
        echo "Error: Directory $project_dir does not exist. Skipping..."
        continue
    fi
    
    cd "$project_dir" || continue
    echo "Changed to directory: $(pwd)"
    
    # Get repository name from remote origin URL, drop the .git suffix
    if git_remote_url=$(git config --get remote.origin.url 2>/dev/null); then
        # Extract repo name from URL and remove .git suffix
        git_repo_name=$(basename -s .git "$git_remote_url")
        echo "Git repository: $git_repo_name"
    else
        echo "Warning: Could not retrieve git repository name. Not a git repository or no remote origin configured."
        git_repo_name="unknown"
    fi
    
    # Set Pulumi backend URL using S3
    folder_name=$(basename "$folder")
    export PULUMI_BACKEND_URL="s3://pulumi-test-$TARGET_ENV-$CURRENT_DATE/$git_repo_name/$folder_name"
    echo "Using Pulumi backend URL: $PULUMI_BACKEND_URL"
    
    # Check if stack exists, create it if not
    if ! pulumi stack select "$TARGET_ENV" 2>/dev/null; then
        echo "Stack $TARGET_ENV does not exist. Creating a new stack..."
        pulumi stack init --stack "$TARGET_ENV" --secrets-provider="awskms://alias/test-pulumi-$TARGET_ENV?region=$AWS_REGION"
        if [ $? -eq 0 ]; then
            echo "Stack $TARGET_ENV created successfully."
        else
            echo "Error: Failed to create stack $TARGET_ENV. Stopping execution."
            exit 1
        fi
    else
        echo "Using existing stack: $TARGET_ENV"
    fi
    
    # Run Pulumi with the specified environment
    echo "Running Pulumi in folder: $folder with action: $ACTION"
    if [[ "$ACTION" == "up" ]]; then
        if ! pulumi up --stack "$TARGET_ENV" --yes; then
            echo "Error: Pulumi up failed in folder $folder. Stopping execution."
            exit 1
        fi
    elif [[ "$ACTION" == "destroy" ]]; then
        if ! pulumi destroy --stack "$TARGET_ENV" --yes; then
            echo "Error: Pulumi destroy failed in folder $folder. Stopping execution."
            exit 1
        fi
    fi
    
    echo "Pulumi $ACTION action on $TARGET_ENV completed successfully for $folder"
    echo "===================================================="
done

echo "All Pulumi $ACTION actions on $TARGET_ENV completed successfully"

