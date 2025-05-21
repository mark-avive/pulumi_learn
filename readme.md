


## IAC code repo format
  <git repo name> : <pulumi project folder>

## Pulumi backends [desired, but not supported pulumi.StackReference]
  S3://<bucket name>/<git repo name>/.pulumi/<pulumi project folder>/<pulumi stack>

## Pulumi backend (singluar) [required for pulumi.StackReference, universal unique project names, single backend for all]
# note cannot have same pulumi project folder name anywhere in IAC repos
  S3://<bucket name>/.pulumi/<pulumi project folder>/<pulumi stack>


## Git repo organization, desired
# <git repo name> : <pulumi project folder>

# VPC IAC 
iac_vpc1 : create_vpc
iac_vpc1 : create_subnets
...
iac_vpc2 : create_vpc
iac_vpc2 : create_subnets
- output vpc info

# EKS IAC
iac_eks1 : create_cluster
iac_eks1 : create_manager_nodes
...
iac_eks2 : create_cluster
iac_eks2 : create_manager_nodes
- input vpc info, output eks info

# App IAC
iac_app1 : create security groups
iac_app1 : create load_balancer
iac_app1 : create sns
iac_app1 : create k8s rbac
...
iac_app2 : create security groups
iac_app2 : create load_balancer
iac_app2 : create sns
iac_app2 : create k8s rbac
- input vpc/eks info, output app info
