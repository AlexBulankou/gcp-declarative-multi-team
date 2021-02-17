terraform {
  backend "gcs" {
    bucket = "alexbu-20210202-multi-team-tfstate"
    prefix = "env/dev"
  }
}
