# datai-gcp-foundation

Template repository for datai project services. Provides Terraform infrastructure, GitHub Actions CI/CD, and GCP bootstrapping scripts for deploying into the shared `datai-core` GCP project with isolated dev/prod environments.

---

## Using this template for a new repo

### Prerequisites

- `gcloud` CLI installed and authenticated as a user with **Project IAM Admin** and **Service Account Admin** on `datai-core`
- The shared Terraform state GCS bucket already exists (created by `tfstate.sh` — see Step 2 if not)
- The Workload Identity Pool `github-pool` and Provider `github-provider` already exist in `datai-core` (created once by `setup_wif.sh` on the first repo — they are reused by all subsequent repos)

---

### Step 1 — Create the new GitHub repository

Create the repo under the `NickMarini` org. The repo name will become the service account name suffix (e.g. repo `datai-website` → SA `datai-website-deployer`).

---

### Step 2 — Provision the Terraform state bucket

Each repo gets its own isolated GCS state bucket.

```bash
# Edit scripts/tfstate.sh and set:
#   REPO_NAME="<your-repo-name>"
chmod +x scripts/tfstate.sh
./scripts/tfstate.sh
```

This creates `datai-state-datai-core-<repo-name>` with versioning and public-access prevention enabled.

Update `terraform/backend.tf` with the bucket name printed in the output:

```hcl
terraform {
  backend "gcs" {
    bucket = "datai-state-datai-core-<your-repo-name>"
    # prefix is injected at init time via -backend-config="prefix=terraform/state/<env>"
  }
}
```

---

### Step 3 — Provision the Service Account and WIF trust

Each repo gets its own dedicated deployer service account scoped to that repository.

```bash
# Edit scripts/setup_wif.sh and set:
#   REPO_NAME="<your-repo-name>"
chmod +x scripts/setup_wif.sh
./scripts/setup_wif.sh
```

Copy the two output values — you will need them in Step 5:
- `GCP_WIF_PROVIDER` — the full Workload Identity Provider resource name
- `GCP_SA_EMAIL` — the service account email

---

### Step 4 — Grant IAM roles to the Service Account

```bash
# Edit scripts/grant_sa_roles.sh and set:
#   SA_NAME="<your-repo-name>-deployer"
chmod +x scripts/grant_sa_roles.sh
./scripts/grant_sa_roles.sh
```

The default role set covers Cloud Run, Artifact Registry, Cloud Build, Cloud SQL, Secret Manager, and GCS. Add or remove roles from the `ROLES` array to match what this service actually deploys.

---

### Step 5 — Configure GitHub repository secrets and variables

In the new repo go to **Settings → Secrets and variables → Actions** and add:

| Type | Name | Value |
|---|---|---|
| Secret | `GCP_WIF_PROVIDER` | Output from Step 3 |
| Secret | `GCP_SA_EMAIL` | Output from Step 3 |
| Variable | `GCP_PROJECT_ID` | `datai-core` |
| Variable | `GCP_REGION` | `europe-west6` |

---

### Step 6 — Update `terraform/main.tf` for this service

1. Update the `locals.name` map — replace or add resource name keys relevant to this service:
   ```hcl
   locals {
     env = var.environment
     name = {
       cloud_run_svc = "my-service-${var.environment}"
       # add further resources here
     }
   }
   ```
2. Remove the placeholder Artifact Registry resource if this service does not need it, and add the actual GCP resources this service requires.

> **Naming convention:** all resource names must include `${var.environment}` (or `local.env`) as a suffix. This guarantees dev and prod resources never collide within the same GCP project.

---

### Step 7 — First deployment

**Deploy dev** (manual, from the Actions tab):
> Actions → **Deploy Dev** → Run workflow

**Deploy prod** (automatic on merge to `main`, or manual):
> Actions → **Deploy Prod** → Run workflow
> — or — merge a PR to `main`

---

## Workflow reference

| Workflow | File | Trigger | State prefix used |
|---|---|---|---|
| Deploy Prod | `deploy.yml` | Push to `main` or manual | `terraform/state/prod` |
| Deploy Dev | `deploy-dev.yml` | Manual only | `terraform/state/dev` |
| Destroy Dev | `destroy-dev.yml` | Manual — must type `destroy` to confirm | `terraform/state/dev` |

> **Destroy is dev-only.** The destroy workflow targets the `terraform/state/dev` state prefix exclusively and hardcodes `environment=dev`. It has no access to the prod state and cannot affect prod resources.

---

## Adding new GCP resources

1. Add an entry to `locals.name` in `main.tf`
2. Write the resource block referencing `local.name["your_key"]`
3. If the resource requires a new API to be enabled, add it to `google_project_service.services`
4. If the SA needs an additional IAM role, add it to `scripts/grant_sa_roles.sh` and re-run it

---

## Files that require changes per new repo

| File | What to change |
|---|---|
| `terraform/backend.tf` | `bucket` — set to the name output by `tfstate.sh` |
| `terraform/main.tf` | `locals.name` map + actual resource blocks |
| `scripts/setup_wif.sh` | `REPO_NAME` |
| `scripts/grant_sa_roles.sh` | `SA_NAME` + role list |
| `scripts/tfstate.sh` | `REPO_NAME` |

