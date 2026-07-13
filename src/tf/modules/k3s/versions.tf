terraform {
  required_providers {
    ansible = { source = "ansible/ansible" }
    aws     = { source = "hashicorp/aws" }
    random  = { source = "hashicorp/random" }
  }
}
