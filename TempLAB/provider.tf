terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "2.38.0"
    }
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = "~> 1.14"
    }
    null = {
      source  = "hashicorp/null"
      version = "3.2.4"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "3.0.2"
    }
    local = {
      source  = "hashicorp/local"
      version = "2.5.3"
    }
    aws = {
      source  = "hashicorp/aws"
      version = "6.16.0"
    }
  }
}

# ---- Providers ----

provider "kubectl" {
  load_config_file = true
  config_path      = "~/.kube/config"
}

provider "kubernetes" {
  config_path = pathexpand("~/.kube/config")
}

provider "helm" {
  kubernetes = {
    config_path = pathexpand("~/.kube/config")
  }
}

provider "aws" {
  region = "us-east-2"
}

