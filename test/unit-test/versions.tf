terraform {
  required_version = "~> 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
    http = {
      version = "~> 3.0"
      source  = "hashicorp/http"
    }
    time = {
      source  = "hashicorp/time"
      version = "~> 0.9"
    }
  }
}
