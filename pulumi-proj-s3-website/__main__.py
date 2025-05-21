import pulumi
from pulumi_aws import s3
import os

# Reference the basic stack
target_env = os.getenv("TARGET_ENV", "unknown")
basic_stack = pulumi.StackReference(f"pulumi-proj-s3-basic/{target_env}")
bucket_id = basic_stack.get_output("bucket_name")

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
