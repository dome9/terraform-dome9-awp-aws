terraform {
  required_providers {
    dome9 = {
      source = "dome9/dome9"
      # version = "1.29.6" # TBD
    }
    aws = {
      source  = "hashicorp/aws"
      version = ">=5.30.0"
    }
    http = {
      source  = "hashicorp/http"
      version = ">=3.4.2"
    }
    local = {
      source  = "hashicorp/local"
      version = "2.5.1"
    }
  }
}
