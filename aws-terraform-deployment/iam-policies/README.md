# IAM Policies for Terraform Configs

Two policies, matching the two configs:

- `terraform-state-bootstrap-policy.json` → for `terraform-state-bootstrap/`
- `terraform-main-env-policy.json` → for `terraform-aws-example/`

## Important: placeholder names must match your real resource names

These policies are scoped to specific resource names/ARNs, not `*`, as a
least-privilege practice. That means you MUST update them if you change
defaults:

- `my-org-terraform-state` → must match `state_bucket_name` in the bootstrap
  config's `variables.tf` (and be your actual globally-unique bucket name)
- `terraform-locks` → must match `lock_table_name`
- `my-app-app-*` → matches the `project_name = "my-app"` default and the
  `name_prefix = "${var.project_name}-app-"` used in the EC2 module's IAM
  role/instance profile. If you change `project_name`, update this too.

If names don't match, you'll get `AccessDenied` errors on resources that
exist but fall outside the ARN patterns you granted.

## How to attach this

Typically as a managed policy attached to an IAM user, group, or role:

```bash
aws iam create-policy \
  --policy-name terraform-state-bootstrap \
  --policy-document file://terraform-state-bootstrap-policy.json

aws iam attach-user-policy \
  --user-name your-iam-user \
  --policy-arn arn:aws:iam::<account-id>:policy/terraform-state-bootstrap
```

Repeat for the main-env policy. If you're using a role (e.g. assumed via SSO
or CI/CD), attach to the role instead of a user.

## Why resource-scoped instead of `*`

Granting `ec2:*`, `iam:*` etc. across the whole account works, but it also
lets Terraform (and anyone using these creds) touch *every* EC2/IAM resource
in the account, not just this project's. Scoping IAM actions to ARN patterns
limits blast radius if credentials leak or a config has a bug.

That said, full resource-level scoping isn't possible for some EC2 actions
(VPC, subnet, route table, NAT gateway, etc. — most don't support
resource-level permissions in IAM, hence `"Resource": "*"` for those in the
main-env policy). This is an AWS API limitation, not a shortcut — you can
narrow it further only with IAM condition keys (e.g. tag-based conditions)
if you want to invest in that.

## Real-world note

In an actual org, you usually won't author/attach these policies yourself —
a platform/security team manages IAM. Bring them this JSON as your specific
ask, rather than requesting blanket admin or `PowerUserAccess`.
