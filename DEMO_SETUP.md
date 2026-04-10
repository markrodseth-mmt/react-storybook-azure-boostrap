# Demo Site Setup Guide

Step-by-step walkthrough to deploy the reference architecture into an Azure subscription and get a working demo site.

---

## What You'll End Up With

- A fully private-networked Azure environment with Front Door, App Services, Redis, AI Search, and Key Vault
- The Astro + Storyblok frontend served at a Front Door URL (e.g. `https://fde-bootstrap-dev-xxxxxx.z01.azurefd.net`)
- All traffic routed through Azure Front Door with WAF protection
- No public endpoints on any backend service

**Estimated time:** 30-40 minutes (mostly waiting for Azure resource provisioning)

**Estimated cost:** ~$30-50/day for dev-tier resources. Destroy when done to avoid charges.

---

## Prerequisites

1. **An Azure subscription** with Owner permissions (or Contributor + User Access Administrator)
2. **Terraform >= 1.14** -- `brew install terraform`
3. **Azure CLI >= 2.55** -- `brew install azure-cli`
4. **A Storyblok space** with an API token (for CMS content). You can create a free space at [storyblok.com](https://www.storyblok.com/)

---

## Step 1: Authenticate to Azure

```bash
az login
```

Set your target subscription:

```bash
az account set --subscription "<your-subscription-id>"
```

Confirm you're in the right place:

```bash
az account show --query "{name:name, id:id}" -o table
```

---

## Step 2: Create the Terraform State Backend

Terraform needs a remote backend to store state. This creates a locked Storage Account:

```bash
# Variables
RG="rg-bootstrap-tfstate"
SA="stbootstraptfstate"
LOCATION="uksouth"

# Create resource group
az group create --name $RG --location $LOCATION

# Create storage account (GRS, no public blob access)
az storage account create \
  --name $SA \
  --resource-group $RG \
  --location $LOCATION \
  --sku Standard_GRS \
  --min-tls-version TLS1_2 \
  --allow-blob-public-access false

# Enable versioning and soft delete
az storage account blob-service-properties update \
  --account-name $SA \
  --resource-group $RG \
  --enable-versioning true \
  --enable-delete-retention true \
  --delete-retention-days 30

# Create the state container
az storage container create \
  --name tfstate \
  --account-name $SA \
  --auth-mode login

# Lock to prevent accidental deletion
az lock create \
  --name DoNotDelete-tfstate \
  --resource-group $RG \
  --lock-type CanNotDelete
```

---

## Step 3: Configure Environment Variables

Edit `terraform/environments/dev/terraform.tfvars`:

```hcl
subscription_id = "<your-subscription-id>"
tenant_id       = "<your-tenant-id>"
```

Find these values with:

```bash
az account show --query "{subscriptionId:id, tenantId:tenantId}" -o table
```

All other values have sensible defaults for a demo. You can leave them as-is.

---

## Step 4: Initialise Terraform

```bash
terraform -chdir=terraform init \
  -backend-config=environments/dev/backend.hcl
```

This downloads providers and configures the remote backend. You should see "Terraform has been successfully initialized!"

---

## Step 5: Review the Plan

```bash
terraform -chdir=terraform plan \
  -var-file=environments/dev/terraform.tfvars
```

Review the output. For a fresh deployment you'll see ~60-70 resources to create, including:

- 2 resource groups
- 1 VNet with 4 subnets
- 9 Private DNS Zones
- 3 App Services (NGINX, Frontend, Backend)
- Azure Front Door with WAF
- Redis, AI Search, Key Vault, ACR
- Function App with storage
- Log Analytics + Application Insights
- ~12 Private Endpoints

---

## Step 6: Deploy

```bash
terraform -chdir=terraform apply \
  -var-file=environments/dev/terraform.tfvars
```

Type `yes` when prompted. This takes **15-25 minutes** — Redis and AI Search are the slowest.

When complete, Terraform prints the outputs:

```
front_door_endpoint = "fde-bootstrap-dev-xxxxxx.z01.azurefd.net"
frontend_app_url    = "https://app-bootstrap-dev-frontend-abc123.azurewebsites.net"
backend_api_url     = "https://app-bootstrap-dev-backend-abc123.azurewebsites.net"
```

Save the `front_door_endpoint` — that's your demo URL.

---

## Step 7: Build and Push the Frontend Image

The frontend needs a container image in ACR. Builds run remotely via ACR Tasks (no local Docker needed):

```bash
# Get the ACR name from Terraform output
ACR_NAME=$(terraform -chdir=terraform output -raw container_registry_login_server | cut -d. -f1)

# Build and push
az acr build \
  --registry $ACR_NAME \
  --image frontend:latest \
  --build-arg STORYBLOK_TOKEN="<your-storyblok-token>" \
  ./apps/frontend
```

---

## Step 8: Set Storyblok Credentials

The frontend App Service needs the Storyblok token at runtime:

```bash
# Get the frontend app name
FRONTEND_APP=$(az webapp list \
  --resource-group rg-bootstrap-dev-main \
  --query "[?contains(name,'frontend')].name" \
  -o tsv)

# Set the token
az webapp config appsettings set \
  --resource-group rg-bootstrap-dev-main \
  --name $FRONTEND_APP \
  --settings STORYBLOK_TOKEN="<your-storyblok-token>"
```

---

## Step 9: Restart the Frontend

After setting credentials and pushing the image, restart to pick up changes:

```bash
az webapp restart \
  --resource-group rg-bootstrap-dev-main \
  --name $FRONTEND_APP
```

---

## Step 10: Verify

### Check Front Door (public entry point)

Open the Front Door endpoint in your browser:

```
https://fde-bootstrap-dev-xxxxxx.z01.azurefd.net
```

It may take 5-10 minutes for Front Door to finish provisioning origins after the initial deploy.

### Check health endpoints

```bash
# Frontend health (via Front Door)
curl -s https://fde-bootstrap-dev-xxxxxx.z01.azurefd.net/health

# API health (via Front Door)
curl -s https://fde-bootstrap-dev-xxxxxx.z01.azurefd.net/api/health
```

### Check logs if something isn't working

```bash
az webapp log tail \
  --resource-group rg-bootstrap-dev-main \
  --name $FRONTEND_APP
```

---

## Tearing Down

When the demo is over, destroy all resources to stop charges:

```bash
terraform -chdir=terraform destroy \
  -var-file=environments/dev/terraform.tfvars
```

**Note:** Redis, AI Search, and Key Vault have `prevent_destroy` lifecycle protection. If destroy fails on these, temporarily remove the `lifecycle` block from the relevant module file, then re-run destroy.

To also remove the state backend:

```bash
az lock delete --name DoNotDelete-tfstate --resource-group rg-bootstrap-tfstate
az group delete --name rg-bootstrap-tfstate --yes
```

---

## Common Issues During Demo Setup

**"Provider produced inconsistent result" on first apply** -- Retry `terraform apply`. Some Azure resources have eventual consistency delays.

**Front Door returns 503** -- Origins take 5-10 minutes to become healthy after initial deployment. Wait and retry.

**ACR build fails with "unauthorized"** -- Run `az acr login --name $ACR_NAME` first, or ensure your identity has ACR Contributor on the registry.

**Frontend shows blank page** -- Check the Storyblok token is set correctly and the Storyblok space has published content. Check logs with `az webapp log tail`.

**Redis/Search takes a long time** -- Normal. Redis can take 10-15 minutes, Search 5-10 minutes on first creation.
