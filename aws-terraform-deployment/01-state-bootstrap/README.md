# Terraform State Bootstrap

Creates the S3 bucket + DynamoDB table that your *other* Terraform configs
use as a remote backend. This has to be applied first, with local state,
because you can't point a config at a backend that doesn't exist yet.

## Usage

1. Edit `variables.tf` — set `state_bucket_name` to something globally unique
   (S3 bucket names are global across all AWS accounts). Change `aws_region`
   if needed.

2. Apply it:
   ```bash
   terraform init
   terraform plan
   terraform apply
   ```

3. Grab the backend config:
   ```bash
   terraform output -raw backend_config_snippet
   ```
   Paste that into your main project's `backend.tf` (uncomment it, replace
   the placeholder values), then run `terraform init` there to migrate to
   remote state.

## What this protects you from

- **Lost/corrupted state**: versioning lets you roll back to a prior state file
- **Concurrent applies stomping each other**: DynamoDB lock table blocks
  simultaneous `apply` runs against the same state key
- **State leakage**: public access fully blocked, SSL-only, encrypted at rest
- **Accidental deletion**: `prevent_destroy` lifecycle rule on the bucket

## Notes

- This bootstrap config's *own* state should stay local, or live in a
  separate, already-existing bucket if you're bootstrapping multiple
  accounts/orgs. Don't try to make it manage its own backend.
- One bucket can hold state for many environments/projects — just vary the
  `key` (e.g. `envs/dev/terraform.tfstate`, `envs/prod/terraform.tfstate`,
  `networking/terraform.tfstate`) rather than creating a bucket per project.
- `prevent_destroy = true` means `terraform destroy` will fail on this bucket
  until you manually remove that line — that's intentional.
