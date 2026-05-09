# All four synthetic providers are configuration-free: they have no
# endpoints, credentials, or runtime authentication to declare. Empty
# provider blocks make their presence explicit and demonstrate the
# pattern derivative frameworks follow when their providers DO require
# configuration (api_endpoint, api_token, region, etc. — see
# proxmox-terraform-framework for a real example).

provider "null" {}

provider "random" {}

provider "local" {}

provider "time" {}
