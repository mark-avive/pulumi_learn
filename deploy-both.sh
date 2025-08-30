#!/bin/bash

# Deploy script with passphrase and proper environment variables

# Configuration
TARGET_ENV="cfndev"
BACKEND_URL="file:///home/mark/workareas/pulumi_learn"
PASSPHRASE="zaq12wsx"

# Set environment variables
export TARGET_ENV
export EXTERNAL_BACKEND_URL="$BACKEND_URL"
export PULUMI_CONFIG_PASSPHRASE="$PASSPHRASE"
export PULUMI_BACKEND_URL="$BACKEND_URL"

# Define directories
BASIC_DIR="/home/mark/workareas/pulumi_learn/pulumi-proj-s3-basic"
WEBSITE_DIR="/home/mark/workareas/pulumi_learn/pulumi-proj-s3-website"

echo "==============================================="
echo "Deploying basic project: $BASIC_DIR"
echo "==============================================="
cd "$BASIC_DIR" || exit 1
echo "Backend URL: $PULUMI_BACKEND_URL"
echo "Stack: $TARGET_ENV"

# Check if stack exists, create if it doesn't
if ! pulumi stack ls | grep -q "$TARGET_ENV"; then
    echo "Creating stack $TARGET_ENV..."
    pulumi stack init "$TARGET_ENV" || exit 1
fi

# Select the stack
pulumi stack select "$TARGET_ENV" || exit 1

# Deploy the basic project
pulumi up --yes || exit 1

echo "==============================================="
echo "Deploying website project: $WEBSITE_DIR"
echo "==============================================="
cd "$WEBSITE_DIR" || exit 1
echo "Backend URL: $PULUMI_BACKEND_URL"
echo "Stack: $TARGET_ENV"

# Check if stack exists, create if it doesn't
if ! pulumi stack ls | grep -q "$TARGET_ENV"; then
    echo "Creating stack $TARGET_ENV..."
    pulumi stack init "$TARGET_ENV" || exit 1
fi

# Select the stack
pulumi stack select "$TARGET_ENV" || exit 1

# Deploy the website project
pulumi up --yes || exit 1

echo "==============================================="
echo "Deployment completed successfully!"
echo "==============================================="
