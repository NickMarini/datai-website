# Centralised naming — add new resources to this map.
# Each value gets "-dev" or "-prod" appended automatically.
locals {
  env = var.environment
  name = {
    docker_repo = "datai-apps-${var.environment}"
  }
}

# 1. Enable necessary GCP APIs automatically
resource "google_project_service" "services" {
  for_each = toset([
    "run.googleapis.com",
    "artifactregistry.googleapis.com",
    "cloudbuild.googleapis.com",
    "iam.googleapis.com"
  ])
  service            = each.key
  disable_on_destroy = false
}

# 2. Create the Docker Repository
resource "google_artifact_registry_repository" "docker_repo" {
  location      = var.region
  repository_id = local.name["docker_repo"]
  description   = "Docker repository for datai.ch applications (${local.env})"
  format        = "DOCKER"

  depends_on = [google_project_service.services]
}