terraform {
  required_version = ">= 1.1.7"
  required_providers {
    aws = {
      source = "hashicorp/aws"
      # https://github.com/hashicorp/terraform-provider-aws/blob/main/CHANGELOG.md
      version               = "~> 4.0"
      configuration_aliases = [aws.ue1]
    }
    local = {
      source = "hashicorp/local"
      # https://github.com/hashicorp/terraform-provider-local/blob/main/CHANGELOG.md
      version = "~> 2.2"
    }
    random = {
      source = "hashicorp/random"
      # https://github.com/hashicorp/terraform-provider-random/blob/main/CHANGELOG.md
      version = "~> 3.1.0"
    }
  }
}
