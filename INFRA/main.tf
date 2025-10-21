# ---- Enable required APIs ----
resource "google_project_service" "compute" {
  project            = var.project
  service            = "compute.googleapis.com"
  disable_on_destroy = false
}

resource "google_project_service" "container" {
  project            = var.project
  service            = "container.googleapis.com"
  disable_on_destroy = false
}

# ---- Service account ----
resource "google_service_account" "default" {
  account_id   = "devops-and-more"
  display_name = "Terraform"
}

# ---- IAM roles ----
resource "google_project_iam_member" "node_sa_storage_admin" {
  project = var.project
  role    = "roles/compute.storageAdmin"
  member  = "serviceAccount:${google_service_account.default.email}"
}

resource "google_project_iam_member" "node_sa_instance_admin" {
  project = var.project
  role    = "roles/compute.instanceAdmin.v1"
  member  = "serviceAccount:${google_service_account.default.email}"
}

resource "google_project_iam_member" "node_sa_log_writer" {
  project = var.project
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.default.email}"
}

resource "google_project_iam_member" "node_sa_metric_writer" {
  project = var.project
  role    = "roles/monitoring.metricWriter"
  member  = "serviceAccount:${google_service_account.default.email}"
}

# ---- GKE cluster ----
resource "google_container_cluster" "primary" {
  name                = "mtwa-cluster"
  location            = "us-central1-a"
  deletion_protection = false
  initial_node_count  = 3

  node_config {
    machine_type    = "e2-standard-4"
    disk_size_gb    = 50
    service_account = google_service_account.default.email
    oauth_scopes    = ["https://www.googleapis.com/auth/cloud-platform"]
    labels          = { foo = "bar" }
    tags            = ["foo", "bar"]
  }

  timeouts {
    create = "30m"
    update = "40m"
  }

  depends_on = [
    google_project_service.compute,
    google_project_service.container,
    google_project_iam_member.node_sa_storage_admin,
    google_project_iam_member.node_sa_instance_admin,
    google_project_iam_member.node_sa_log_writer,
    google_project_iam_member.node_sa_metric_writer
  ]
}

# ---- Fetch kubeconfig ----
resource "null_resource" "fetch_kubeconfig" {
  depends_on = [google_container_cluster.primary]

  provisioner "local-exec" {
    command = "gcloud container clusters get-credentials mtwa-cluster --zone us-central1-a --project ${var.project}"
  }
}

# ---- Static IP for Load Balancer ----
resource "google_compute_address" "gitlab_lb" {
  name         = "gitlab-nginx-lb-ip"
  region       = var.region
  address_type = "EXTERNAL"
  network_tier = "PREMIUM"
}

# ---- Save IP locally ----
resource "local_file" "lb_ip_txt" {
  content  = google_compute_address.gitlab_lb.address
  filename = "${path.module}/lb_ip.txt"
}
