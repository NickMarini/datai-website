locals {
  env             = terraform.workspace
  hosting_site_id = "datai-portfolio-${local.env}"
}

# 1. Enable Core APIs (Safe to execute across both workspaces)
resource "google_project_service" "services" {
  for_each = toset([
    "firebase.googleapis.com",
    "firebasehosting.googleapis.com",
    "iam.googleapis.com"
  ])
  provider           = google-beta
  service            = each.key
  disable_on_destroy = false
}

# 2. Initialize Firebase on the GCP Project 
# SINGLETON: Only the 'prod' workspace execution handles this project-level resource
resource "google_firebase_project" "default" {
  count      = local.env == "prod" ? 1 : 0
  provider   = google-beta
  project    = var.project_id
  depends_on = [google_project_service.services]
}

# 3. Create Environment-Isolated Hosting Sites
# Each workspace manages ONLY its own infrastructure target
resource "google_firebase_hosting_site" "portfolio_site" {
  provider   = google-beta
  project    = var.project_id
  site_id    = local.hosting_site_id
  depends_on = [google_project_service.services]
}