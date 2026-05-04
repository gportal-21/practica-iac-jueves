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
  }
}

provider "docker" {
  # Configuration options
}

provider "aws" {
  profile = "gpdev"
}
