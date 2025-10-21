terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
    null = {
      source  = "hashicorp/null"
      version = "3.2.4"
    }
  }
}

provider "google" {
  project     = var.project
  region      = var.region
  credentials = file("accesskeys.json")
}
