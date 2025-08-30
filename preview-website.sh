#!/bin/bash

# Preview script with passphrase and proper environment variables

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
echo "Testing component installation"
echo "==============================================="
cd /home/mark/workareas/pulumi_fetch_backend/fetch_backend_outputs_cli || exit 1
pip install -e .

echo "==============================================="
echo "Previewing website project: $WEBSITE_DIR"
echo "==============================================="
cd "$WEBSITE_DIR" || exit 1
echo "Backend URL: $PULUMI_BACKEND_URL"
echo "Stack: $TARGET_ENV"

# Select the stack
pulumi stack select "$TARGET_ENV" || exit 1

# Preview the website project
pulumi preview --debug || exit 1

echo "==============================================="
echo "Preview completed!"
echo "==============================================="
