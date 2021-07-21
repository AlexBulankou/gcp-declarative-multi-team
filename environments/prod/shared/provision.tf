variable "project" {
  type = string
}

variable "sync_repo" {
  type = string
}

variable "sync_branch" {
  type = string
}

variable "policy_dir" {
  type = string
}

locals {
  region = "us-central1"
  zone   = "us-central1-b"
}

provider "google-beta" {
  region = local.region
  zone   = local.zone
  project = var.project
}

resource "google_project_service" "iamservice" {
  project = var.project
  service = "iam.googleapis.com"

  disable_dependent_services = true
}

resource "google_project_service" "crmservice" {
  project = var.project
  service = "cloudresourcemanager.googleapis.com"

  disable_dependent_services = true
}


resource "google_project_service" "containerservice" {
  project = var.project
  service = "container.googleapis.com"

  disable_dependent_services = true

  depends_on = [
    google_project_service.crmservice,
    google_project_service.iamservice
  ]
}

resource "google_project_service" "gkehubservice" {
  project = var.project
  service = "gkehub.googleapis.com"

  disable_dependent_services = true

  depends_on = [
    google_project_service.containerservice
  ]
}

resource "google_project_service" "acmservice" {
  project = var.project
  service = "anthosconfigmanagement.googleapis.com"

  disable_dependent_services = true

  depends_on = [
    google_project_service.containerservice
  ]
}

resource "google_container_cluster" "primary" {
  provider = google-beta
  name      = "cluster-1"
  project = var.project
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
    google_project_service.containerservice,
    google_project_service.gkehubservice
  ]
}

resource "google_container_node_pool" "primary_preemptible_nodes" {
  name       = "primary-node-pool"
  project = var.project
  cluster    = google_container_cluster.primary.name
  location   = local.zone
  node_count = 7

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
  project = var.project
  display_name = "IAM service account used by Config Connector"
}

resource "google_project_iam_member" "project" {
  project = var.project
  role    = "roles/owner"
  member = "serviceAccount:${google_service_account.cnrmsa.email}"
  depends_on = [
    google_service_account.cnrmsa
  ]
}

resource "google_service_account_iam_binding" "admin-account-iam" {
  service_account_id = google_service_account.cnrmsa.name
  role               = "roles/iam.workloadIdentityUser"

  members = [
    "serviceAccount:${var.project}.svc.id.goog[cnrm-system/cnrm-controller-manager]",
  ]

  depends_on = [
    google_container_cluster.primary,
    google_service_account.cnrmsa
  ]
}

resource "google_gke_hub_membership" "membership" {
  membership_id = "hub-membership"
  endpoint {
    gke_cluster {
      resource_link = "//container.googleapis.com/${google_container_cluster.primary.id}"
    }
  }
  depends_on = [
    google_project_service.gkehubservice
  ]
  provider = google-beta
}

resource "google_gke_hub_feature" "acm_feature" {
  name = "configmanagement"
  location = "global"
  depends_on = [
    google_project_service.gkehubservice,
    google_project_service.acmservice
  ]
  provider = google-beta
}

resource "google_gke_hub_feature_membership" "acm_feature_member" {
  location = "global"
  feature = google_gke_hub_feature.acm_feature.name
  membership = google_gke_hub_membership.membership.membership_id
  configmanagement {
    version = "1.6.2"
    config_sync {
      git {
        sync_repo = var.sync_repo
        sync_branch = var.sync_branch
        policy_dir = var.policy_dir
        secret_type = "none"
      }
    }
  }
  depends_on = [
    google_project_service.gkehubservice
  ]
  provider = google-beta
}