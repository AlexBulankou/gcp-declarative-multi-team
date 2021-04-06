terraform {
  backend "gcs" {
    bucket = "alexbu-20210402-dev-tfstate"
    prefix = "env/dev"
  }
}
