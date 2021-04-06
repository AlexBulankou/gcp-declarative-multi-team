terraform {
  backend "gcs" {
    bucket = "alexbu-20210402-prod-2-tfstate"
    prefix = "env/prod"
  }
}
