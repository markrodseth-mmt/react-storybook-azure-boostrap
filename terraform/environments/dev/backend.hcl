# backend.hcl - passed to terraform init via:
#   terraform init -backend-config=environments/dev/backend.hcl

resource_group_name  = "rg-bootstrap-tfstate"
storage_account_name = "stbootstraptfstate"
container_name       = "tfstate"
key                  = "dev/terraform.tfstate"
