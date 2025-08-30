import pulumi
from pulumi_aws import s3
import os
from fetch_backend_outputs_cli import PulumiStackOutputs

# Get the target environment
target_env = os.getenv("TARGET_ENV", "unknown")

# Option 1: Using the new component to fetch outputs from another backend
# This is more robust and can handle different backends
basic_outputs = PulumiStackOutputs(
    "basic-stack-outputs",
    project="pulumi-proj-s3-basic",
    stack=target_env,
    backend_url=os.getenv("EXTERNAL_BACKEND_URL", "file:///home/mark/workareas/pulumi_learn")
)
bucket_id = basic_outputs.outputs.get("bucket_name_unique")

# Option 2 (fallback): Use the standard StackReference if the component doesn't work
# This is kept as a fallback, but commented out
# basic_stack = pulumi.StackReference(f"pulumi-proj-s3-basic/{target_env}")
# bucket_id = basic_stack.get_output("bucket_name")

# Import the existing bucket as a Pulumi resource
bucket = s3.BucketV2.get("imported-bucket", id=bucket_id)

# Turn the bucket into a website:
website = s3.BucketWebsiteConfigurationV2("website",
    bucket=bucket.id,
    index_document={
        "suffix": "index.html",
    })

# Permit access control configuration:
ownership_controls = s3.BucketOwnershipControls(
    'ownership-controls',
    bucket=bucket.id,
    rule={
        "object_ownership": 'ObjectWriter',
    },
)

# Enable public access to the website:
public_access_block = s3.BucketPublicAccessBlock(
    'public-access-block', bucket=bucket.id, block_public_acls=False
)

# Create an S3 Bucket object
bucket_object = s3.BucketObject(
    'index.html',
    bucket=bucket.id,
    source=pulumi.FileAsset('index.html'),
    content_type='text/html',
    acl='public-read',
    opts=pulumi.ResourceOptions(depends_on=[ownership_controls, public_access_block]),
)

# Export the bucket's autoassigned URL:
pulumi.export('url', pulumi.Output.concat('http://', website.website_endpoint))
