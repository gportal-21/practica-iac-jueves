terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "4.2.0"
    }

    aws = {
      source  = "hashicorp/aws"
      version = "6.42.0"
    }

    archive = {
      source  = "hashicorp/archive"
      version = "2.7.1"
    }
  }
}

provider "archive" {
  # Configuration options
}

provider "docker" {
  # Configuration options
}

provider "aws" {
  profile = "tu_profile_aws"
}
