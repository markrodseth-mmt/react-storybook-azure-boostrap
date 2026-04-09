# Quadient Azure Infrastructure Bootstrap

Terraform bootstrap and CLI for the Quadient reference architecture:
Azure Front Door Premium, App Services (NGINX + Frontend + Backend), Redis, AI Search, Function App -- all private-networked via VNet + Private Endpoints.

---

## Architecture

```
Internet --> Azure Front Door Premium (WAF + CDN + DDoS)
                |
                | Private Link
                |
       +--------+--------+
       |        |        |
   /api/*   /r/*,     /*
       |   /redirect/*   |
       |        |        |
   Backend   NGINX   Frontend
   (.NET)  (redirects) (Astro+Storyblok)
       |                 |
       +--------+--------+
                |
        VNet (Private Endpoints)
                |
    +-----------+-----------+
    |           |           |
  Redis    AI Search    Key Vault
    |
  Function App
  (Data Sync)
    |
  Storage Account
```

All services sit behind private endpoints inside a VNet. No public endpoints are exposed.
Azure Front Door reaches App Services via Private Link (AFD Premium integration).

---

## What Gets Created

| Resource | Name Pattern | SKU (dev / prod) | Purpose |
|----------|-------------|-------------------|---------|
| Resource Groups | `rg-quadient-{env}-main`, `-networking` | -- | Resource organisation |
| Virtual Network | `vnet-quadient-{env}` | -- | Private networking for all services |
| Subnets (x4) | `snet-quadient-{env}-*` | -- | App Services, Private Endpoints, Functions |
| NSGs | `nsg-quadient-{env}-app-services` | -- | Allow AFD + VNet only, deny internet |
| Private DNS Zones | `privatelink.*.net` | -- | DNS resolution for private endpoints |
| Azure Front Door | `afd-quadient-{env}` | Premium | Global load balancing, WAF, CDN, TLS |
| WAF Policy | `waf*policy` | Detection / Prevention | OWASP + Bot protection |
| App Service Plan (NGINX) | `asp-quadient-{env}-nginx` | P1v3 / P3v3 | Dedicated plan for redirect workload |
| App Service Plan (apps) | `asp-quadient-{env}-apps` | P1v3 / P2v3 | Shared plan for frontend + backend |
| Web App (NGINX) | `app-quadient-{env}-nginx-*` | -- | High-volume redirects and routing rules |
| Web App (Frontend) | `app-quadient-{env}-frontend-*` | -- | Astro + Storyblok SSR application |
| Web App (Backend) | `app-quadient-{env}-backend-*` | -- | .NET minimal API with Fusion Cache |
| Container Registry | `acr*` | Premium | Docker images with geo-replication |
| Function App | `func-quadient-{env}-datasync-*` | Elastic Premium EP1 | Data synchronisation between systems |
| Storage Account | `st*fn*` | Standard LRS | Function App runtime storage |
| Redis Cache | `redis-quadient-{env}` | Standard C0 / C1 | Application caching |
| AI Search | `srch-quadient-{env}` | Basic / Standard | Full-text search |
| Key Vault | `kv-quadient-{env}` | Standard | Secrets management (RBAC-enabled) |
| Log Analytics | `law-quadient-{env}` | PerGB2018 | Centralised logging and diagnostics |

---

## Prerequisites

| Tool | Version | Install |
|------|---------|---------|
| [Terraform](https://developer.hashicorp.com/terraform/install) | >= 1.6 | `brew install terraform` |
| [Azure CLI](https://learn.microsoft.com/en-us/cli/azure/install-azure-cli) | >= 2.55 | `brew install azure-cli` |
| [Infracost](https://www.infracost.io/docs/) | >= 0.10 | Optional -- cost estimation |

Docker is **not** required. Container builds run remotely via ACR Tasks.

### Required Azure Permissions

The deploying identity (user or service principal) needs these roles on the target subscription:

| Role | Why |
|------|-----|
| **Owner** (or Contributor + User Access Administrator) | Create resources and assign RBAC roles (ACR Pull, Key Vault) |
| **Key Vault Administrator** | Auto-assigned by Terraform on the Key Vault for secret management |

---

## Project Structure

```
quadient-bootstrap/
├── apps/
│   └── frontend/                    # Astro + React + Storyblok frontend
│       ├── src/
│       │   ├── layouts/             # Base HTML layout
│       │   ├── pages/               # Catch-all slug route + /health endpoint
│       │   └── storyblok/           # Component mappings (Page, Hero, RichText, Image)
│       ├── Dockerfile               # Multi-stage build for ACR
│       └── package.json
│
├── cli/
│   └── infra                        # Unified CLI for all operations
│
└── terraform/
    ├── providers.tf                 # AzureRM v4 + AzureAD provider config
    ├── variables.tf                 # All input variables
    ├── main.tf                      # Root module — wires all modules together
    ├── outputs.tf                   # Root outputs (URLs, endpoints)
    │
    ├── modules/
    │   ├── networking/              # VNet, subnets, NSGs, Private DNS Zones
    │   ├── front_door/              # AFD Premium, WAF, CDN, routes, custom domains
    │   ├── app_services/            # NGINX, Frontend (Astro + Storyblok), Backend (.NET)
    │   ├── container_registry/      # ACR Premium + geo-replication
    │   ├── function_app/            # Data Sync Function App (Elastic Premium)
    │   ├── search/                  # Azure AI Search
    │   ├── redis/                   # Azure Redis Cache
    │   ├── key_vault/               # Key Vault (RBAC-enabled) + Private Endpoint
    │   └── monitoring/              # Log Analytics + diagnostic settings
    │
    └── environments/
        ├── dev/
        │   ├── terraform.tfvars     # Dev-sized SKUs, WAF in Detection mode
        │   └── backend.hcl          # Remote state backend pointer
        └── prod/
            ├── terraform.tfvars     # Production SKUs, WAF in Prevention mode
            └── backend.hcl
```

---

## First-time Setup (per client tenant)

### 1. Authenticate

```bash
./cli/infra login dev
```

### 2. Create remote state backend

Creates a Storage Account (GRS, soft delete, resource lock) to hold `.tfstate` files.

```bash
./cli/infra bootstrap dev <subscription-id>
```

### 3. Update variables

Edit `terraform/environments/dev/terraform.tfvars`:

```hcl
subscription_id = "<client-subscription-id>"
tenant_id       = "<client-tenant-id>"
```

### 4. Initialise Terraform

```bash
./cli/infra init dev
```

### 5. Plan

```bash
./cli/infra plan dev
```

Review the plan output carefully, especially:
- Private DNS Zone names (must not conflict with existing zones in the subscription)
- Subnet address spaces (must not overlap with existing VNets if peered)
- AFD WAF mode (`Detection` in dev, `Prevention` in prod)

### 6. Apply

```bash
./cli/infra apply dev
```

### 7. Set Storyblok credentials

Storyblok secrets are managed outside of Terraform to avoid storing them in state:

```bash
./cli/infra secrets:set dev
```

---

## Day-to-day Operations

### Build and push a container image

Builds run remotely via ACR Tasks -- no local Docker needed:

```bash
./cli/infra acr:build dev frontend:v1.2.3 ./apps/frontend
./cli/infra acr:build dev backend-api:v2.0.0 ./apps/backend
```

### Stream live logs from an App Service

```bash
./cli/infra app:logs dev frontend
./cli/infra app:logs dev backend
./cli/infra app:logs dev nginx
```

### Purge CDN cache after a deployment

```bash
./cli/infra afd:purge dev /
./cli/infra afd:purge prod /static/*
```

### Rotate Redis credentials

```bash
./cli/infra secrets:rotate-redis prod
```

This regenerates the Redis primary key and updates the Key Vault secret, backend App Service connection string, and Function App app setting automatically.

### Get a cost estimate

```bash
./cli/infra cost dev
./cli/infra cost prod
```

---

## Promoting dev to prod

Prod uses a different subscription, higher SKUs, WAF in Prevention mode, and requires custom domain DNS validation.

**Before your first prod deploy:**

1. Copy and edit `terraform/environments/prod/terraform.tfvars`:
   ```hcl
   subscription_id = "<prod-subscription-id>"
   tenant_id       = "<prod-tenant-id>"
   custom_domains  = ["www.yourdomain.com", "api.yourdomain.com"]
   ```

2. Create the prod state backend:
   ```bash
   ./cli/infra bootstrap prod <prod-subscription-id>
   ```

3. Initialise, plan, and apply:
   ```bash
   ./cli/infra init prod
   ./cli/infra plan prod    # Review carefully -- prod uses Prevention WAF mode
   ./cli/infra apply prod
   ```

4. After apply, create CNAME records pointing your custom domains to the Front Door endpoint. AFD will automatically provision TLS certificates once DNS validation passes.

5. Set prod secrets:
   ```bash
   ./cli/infra secrets:set prod
   ```

---

## Key Design Decisions

### Network topology
All App Services, Functions, Redis, Search, and ACR are accessed exclusively via Private Endpoints inside the VNet. Azure Front Door reaches App Services via the AFD Premium Private Link integration.

### Managed identity
All App Services and the Function App use System-assigned Managed Identity to pull images from ACR. No ACR admin credentials are used or stored. Key Vault uses Azure RBAC (not access policies) for authorization.

### Storyblok CMS
Storyblok is externally hosted. The Frontend App Service accesses it over the internet (outbound via VNet). Credentials are stored in App Settings (set via `infra secrets:set`) and never in Terraform state or source control.

### Certificates
TLS is terminated at Azure Front Door. Certificates are managed by AFD with auto-renewal. For custom domains, AFD handles DigiCert issuance automatically once CNAME validation passes.

### State locking
The Azure Blob Storage backend provides automatic lease-based state locking. No additional configuration is needed -- concurrent `terraform apply` runs will wait or fail safely.

### Stateful resource protection
Redis, AI Search, and Key Vault have `lifecycle { prevent_destroy = true }` to guard against accidental deletion. To intentionally destroy these, you must first remove the lifecycle block.

---

## Sensitive Variables

**Never commit secrets to source control.** The prod `terraform.tfvars` is gitignored.

| Variable | How to set |
|----------|-----------|
| `subscription_id` / `tenant_id` | Edit `terraform.tfvars` per environment |
| Storyblok API token | `./cli/infra secrets:set <env>` (interactive) |
| Redis connection string | Auto-managed by `./cli/infra secrets:rotate-redis` |

---

## Destroying an environment

```bash
./cli/infra destroy dev
```

You will be asked to type the environment name to confirm.

**Note:** The resource group `rg-quadient-tfstate` (Terraform state) is not destroyed. To clean up completely:
```bash
# Remove the resource lock first
az lock delete --name DoNotDelete-tfstate --resource-group rg-quadient-tfstate
# Then delete the resource group
az group delete --name rg-quadient-tfstate --yes
```

---

## Troubleshooting

**`Error: A resource with the ID already exists`**
Import the existing resource: `./cli/infra state:import <env> <tf-addr> <azure-id>`

**Private endpoint DNS not resolving**
Check Private DNS Zone links: ensure the VNet link exists for `privatelink.azurewebsites.net`

**App Service can't pull image from ACR**
Confirm Managed Identity has `AcrPull` role: `az role assignment list --assignee <principal-id>`

**AFD returns 503 to origins**
Check origin health: `./cli/infra afd:origins <env>` -- App Services must allow AFD backend IPs via service tag `AzureFrontDoor.Backend`

**Key Vault access denied (403)**
The Key Vault uses Azure RBAC. Ensure the calling identity has the `Key Vault Secrets User` role (or `Key Vault Administrator` for write operations).

**`lifecycle { prevent_destroy }` blocking destroy**
Redis, Search, and Key Vault are protected. To destroy, temporarily comment out the lifecycle block in the relevant module, run `terraform plan`, then `terraform apply`.
