terraform {
  backend "gcs" {
    bucket = "alexbu-test-20210720-tfstate"
    prefix = "env/prod"
  }
}
