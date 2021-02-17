locals {
  region = "us-central1"
  zone   = "us-central1-b"
}

provider "google-beta" {
  region = local.region
  zone   = local.zone
  project = "${var.project}"
}


resource "google_project_service" "crmservice" {
  project = "${var.project}"
  service = "cloudresourcemanager.googleapis.com"

  disable_dependent_services = true
}

resource "google_project_service" "containerservice" {
  project = "${var.project}"
  service = "container.googleapis.com"

  disable_dependent_services = true

  depends_on = [
    google_project_service.crmservice
  ]
}

resource "google_container_cluster" "primary" {
  provider = google-beta
  name      = "cluster-1"
  project   = "${var.project}"
  location  = local.zone

  # We can't create a cluster with no node pool defined, but we want to only use
  # separately managed node pools. So we create the smallest possible default
  # node pool and immediately delete it.
  remove_default_node_pool = true
  initial_node_count = 1

  master_auth {
    username = ""
    password = ""

    client_certificate_config {
      issue_client_certificate = false
    }
  }

  workload_identity_config {
        identity_namespace = "${var.project}.svc.id.goog"
    }

  addons_config {
    config_connector_config {
      enabled = true
    }
}

  depends_on = [
    google_project_service.containerservice
  ]
}

resource "google_container_node_pool" "primary_preemptible_nodes" {
  name       = "primary-node-pool"
  project    = "${var.project}"
  cluster    = google_container_cluster.primary.name
  location   = local.zone
  node_count = 3

  node_config {
    preemptible  = true
    machine_type = "e2-medium"

    metadata = {
      disable-legacy-endpoints = "true"
    }

    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]
  }
}

resource "google_service_account" "cnrmsa" {
  account_id   = "cnrmsa"
  project = "${var.project}"
  display_name = "IAM service account used by Config Connector"
}

resource "google_project_iam_binding" "project" {
  project = "${var.project}"
  role    = "roles/owner"

  members = [
    "serviceAccount:${google_service_account.cnrmsa.email}",
  ]

  depends_on = [
    google_service_account.cnrmsa
  ]
}

resource "google_service_account_iam_binding" "admin-account-iam" {
  service_account_id = google_service_account.cnrmsa.name
  role               = "roles/iam.workloadIdentityUser"

  members = [
    "serviceAccount:${google_project.root_project.project_id}.svc.id.goog[cnrm-system/cnrm-controller-manager]",
  ]

  depends_on = [
    google_container_cluster.primary,
    google_service_account.cnrmsa
  ]
}