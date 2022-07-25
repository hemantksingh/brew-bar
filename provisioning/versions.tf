terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 3.50.0"
    }

    random = {
      source  = "hashicorp/random"
      version = "3.1.0"
    }

    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.2.0"
    }

    local = {
      source  = "hashicorp/local"
      version = "2.1.0"
    }
    null = {
      source  = "hashicorp/null"
      version = ">= 2.0"
    }
  }

  required_version = "> 0.14"
}
