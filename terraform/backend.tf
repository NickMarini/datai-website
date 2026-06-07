terraform {
  backend "gcs" {
    bucket = "datai-state-datai-core-datai-website"
    # prefix is injected at init time via -backend-config="prefix=terraform/state/<env>"
  }
}