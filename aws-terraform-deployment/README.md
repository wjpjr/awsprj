# AWS Environment Deployment — Full Walkthrough

This package stands up a complete, properly structured AWS environment:
remote state backend, then a VPC + private EC2 instance, with least-privilege
IAM policies for whoever's running it.

```
.
├── iam-policies/           Permission docs for whoever grants you access
├── 01-state-bootstrap/     Run FIRST — creates S3 bucket + DynamoDB lock table
└── 02-main-environment/    Run SECOND — VPC + EC2, using remote state
```

## Prerequisites

- [Terraform](https://developer.hashicorp.com/terraform/install) >= 1.5.0
- An AWS account + credentials configured (`aws configure`, SSO, or assumed role)
- IAM permissions matching `iam-policies/*.json` (see that folder's README if
  you need to request access from a platform/security team)

Verify credentials are active before doing anything:
```bash
aws sts get-caller-identity
```

---

## Step 1 — Bootstrap remote state

This creates the S3 bucket and DynamoDB table that the main environment will
store its state in. Its own state stays local — nothing to bootstrap here.

```bash
cd 01-state-bootstrap

# Edit variables.tf first:
#   - state_bucket_name: must be globally unique across ALL of AWS
#   - aws_region: change if needed

terraform init
terraform plan
terraform apply
```

Grab the backend config you'll need next:
```bash
terraform output -raw backend_config_snippet
```

## Step 2 — Deploy the main environment

```bash
cd ../02-main-environment

# Paste the output from Step 1 into backend.tf, uncommenting the block
# and replacing the placeholder bucket/table/region values.
```

Then customize `variables.tf` for your case — at minimum:
- `ssh_allowed_cidr`: restrict to your actual VPN/office IP, never `0.0.0.0/0`
- `project_name`: used for naming/tagging everything
- `key_pair_name`: leave blank to skip SSH entirely (SSM is enabled by default,
  so you can connect via `aws ssm start-session` without a key pair at all)

```bash
terraform init    # pulls in the S3 backend; migrates state there
terraform plan    # review what will be created
terraform apply
```

Confirm it's up:
```bash
terraform output app_instance_id
aws ec2 describe-instances --instance-ids $(terraform output -raw app_instance_id)
```

Connect without SSH, via SSM:
```bash
aws ssm start-session --target $(terraform output -raw app_instance_id)
```

---

## Tear-down order (reverse of deployment)

```bash
cd 02-main-environment
terraform destroy

cd ../01-state-bootstrap
# Note: prevent_destroy is set on the state bucket. You must remove
# that lifecycle block in main.tf before destroy will succeed here.
terraform destroy
```

Tear down the main environment *before* the bootstrap — the main environment's
state lives in that S3 bucket, so destroying the bucket first would leave you
unable to cleanly destroy the EC2/VPC resources via Terraform.

---

## What you get

| Layer | Resources |
|---|---|
| State backend | S3 bucket (versioned, encrypted, SSL-only, public access blocked), DynamoDB lock table |
| Networking | VPC, public + private subnets across 2 AZs, IGW, NAT gateway, route tables |
| Compute | EC2 instance in private subnet, IAM role w/ SSM (no SSH key required), encrypted gp3 volume, IMDSv2 enforced |
| Security | Security group with least-privilege ingress, no public IP on the instance |

## Common gotchas

- **`AccessDenied` on apply**: check `iam-policies/README.md` — your IAM
  identity needs permissions matching the resources being created, and the
  bundled policy JSON is scoped to default names (e.g. `my-app-app-*`). If
  you change `project_name`, update the policy ARNs too.
- **S3 bucket name already taken**: bucket names are global across all AWS
  accounts, not just yours. Pick something unique (e.g. prefix with your org
  name).
- **`terraform init` fails on backend migration**: make sure the bootstrap
  step finished successfully and the bucket/table names in `backend.tf`
  exactly match what was created.
- **Can't destroy the state bucket**: that's intentional (`prevent_destroy`).
  Remove the lifecycle block first if you really mean to delete it.

## Natural next additions

Not included here, but straightforward extensions if you need them:
- Application Load Balancer + target group, for public-facing access
- RDS database in the private subnets
- Auto Scaling Group instead of a single instance
- GitHub Actions / GitLab CI pipeline running `plan` on PRs and `apply` on merge
