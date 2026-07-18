terraform {
    required_version = ">= 1.5"

    required_providers {
      multipass = {
        source = "larstobi/multipass"
        version = "~> 1.4"
      }
    }
}

provider "multipass" {}