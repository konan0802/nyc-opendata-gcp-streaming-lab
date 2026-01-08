terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = "us-central1"
}

variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

# テスト: プロジェクト情報を取得
data "google_project" "project" {
  project_id = var.project_id
}

output "project_name" {
  value = data.google_project.project.name
}

output "project_number" {
  value = data.google_project.project.number
}

