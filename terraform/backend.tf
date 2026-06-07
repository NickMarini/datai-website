terraform {
  backend "gcs" {
    bucket = "datai-tf-state-datai-core"
    # prefix is injected at init time via -backend-config="prefix=terraform/state/<env>"
  }
}