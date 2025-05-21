
## Pulumi backends (desired many, pulumi not supported)
- [not supported by pulumi.StackReference]
- S3://\<s3 bucket name\>/\<git repo name\>/.pulumi/\<pulumi project folder\>/\<pulumi stack name\>

## Pulumi backend (can be only one, only supported way)
- [required for pulumi.StackReference, must have unique project folder names in all IAC in backend, single backend for all for stack references]
- S3://\<bucket name\>/.pulumi/\<pulumi project folder\>/\<pulumi stack\>
  - note cannot have same \<pulumi project folder\> name anywhere in or accross IAC repos

## Question
- What is LOE to get pulumi.StackReference to take a backend parameter?

## Git repo organization format, desired
- \<git repo name1\> : \<pulumi project folder1\>
- \<git repo name1\> : \<pulumi project folder2\>
- \<git repo name2\> : \<pulumi project folder1\>
- \<git repo name2\> : \<pulumi project folder2\>

# Example IAC repo/folder setup
- note: cannot reuse \<pulumi project folder\> names when all IAC code is using a single backend, as folder names in the example setup below is showing.
- note: index numbers below [1...X] indicate different IAC resource provisioning code, not variances in provided config values and are not indicators of different stacks used to run the IAC code
- note: output names would commonly be the same in each repo type/folder purpose:
  - ex: iac_vpc1:create_vpc/  ... iac_vpcX:create_vpc/
    - all would produce output named: vpc_id
- end result: take example case app1 needs to be setup on to eks2:
  - different backends: all IAC code can be same and simply setup to use appropriate backends [as is the case with terraform]
    - iac code would reference same folder and output name in the configured backend
  - everything in same backend: then code needs be written to handle [1...X] variance as the backend folder paths (and/or output name) cannot be the same for each [1...X]
    - after code getting correct output [1...x], may need to map/normalize variable to use in the IAC code

### VPC IAC
- outputs vpc info
```
iac_vpc1 : create_vpc/
iac_vpc1 : create_subnets/
...
iac_vpcX : create_vpc/
iac_vpcX : create_subnets/

```

### EKS IAC
- Eks IAC code needs inputs from vpc, outputs eks info
```
iac_eks1 : create_cluster/
iac_eks1 : create_manager_nodes/
...
iac_eksX : create_cluster/
iac_eksX : create_manager_nodes/
```
### App IAC
- App IAC code needs inputs from vpc/eks, outputs app info
- Depending on app hierarchy, one app may need inpuits from another app
```
iac_app1 : create_security_groups/
iac_app1 : create_load_balancer/
iac_app1 : create_sns/
iac_app1 : create_k8s_rbac/
...
iac_appX : create_security_groups/
iac_appX : create_load_balancer/
iac_appX : create_sns/
iac_appX : create_k8s_rbac/
```
