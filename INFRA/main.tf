# ---- Enable required APIs ----
# These resources activate the necessary Google Cloud APIs for Compute Engine and GKE (Kubernetes Engine)
# so that Terraform can later create VMs, clusters, and networking resources.
resource "google_project_service" "compute" {
  project            = var.project
  service            = "compute.googleapis.com"     # Enables the Compute Engine API
  disable_on_destroy = false                        # Keeps the API enabled even if this resource is destroyed
}

resource "google_project_service" "container" {
  project            = var.project
  service            = "container.googleapis.com"   # Enables the Kubernetes Engine (GKE) API
  disable_on_destroy = false
}

# ---- Service account ----
# Creates a dedicated service account that Terraform and GKE nodes will use to authenticate to Google Cloud.
resource "google_service_account" "default" {
  account_id   = "devops-and-more"   # Unique ID of the service account
  display_name = "Terraform"         # name in GCP console
}

# ---- IAM roles ----
# Grants the service account the necessary IAM permissions to manage instances,
# storage, logs, and metrics for the GKE cluster.
resource "google_project_iam_member" "node_sa_storage_admin" {
  project = var.project
  role    = "roles/compute.storageAdmin"                 # Permission to manage storage disks for nodes
  member  = "serviceAccount:${google_service_account.default.email}"
}

resource "google_project_iam_member" "node_sa_instance_admin" {
  project = var.project
  role    = "roles/compute.instanceAdmin.v1"             # Permission to manage VM instances
  member  = "serviceAccount:${google_service_account.default.email}"
}

resource "google_project_iam_member" "node_sa_log_writer" {
  project = var.project
  role    = "roles/logging.logWriter"                    # Permission to write logs to Cloud Logging
  member  = "serviceAccount:${google_service_account.default.email}"
}

resource "google_project_iam_member" "node_sa_metric_writer" {
  project = var.project
  role    = "roles/monitoring.metricWriter"              # Permission to publish metrics to Cloud Monitoring
  member  = "serviceAccount:${google_service_account.default.email}"
}

# ---- GKE cluster ----
# Creates a Google Kubernetes Engine cluster named "mtwa-cluster"
# with 3 nodes, using the previously created service account and IAM roles.
resource "google_container_cluster" "primary" {
  name                = "mtwa-cluster"
  location            = "us-central1-a"
  deletion_protection = false            # Allows Terraform to delete the cluster when destroyed
  initial_node_count  = 3                # Number of nodes in the default node pool

  node_config {
    machine_type    = "e2-standard-4"   # Node machine size (4 vCPUs, 16GB RAM)
    disk_size_gb    = 50                # Disk size for each node
    service_account = google_service_account.default.email   # Attach the created service account to nodes
    oauth_scopes    = ["https://www.googleapis.com/auth/cloud-platform"]  # Full GCP access for the nodes
    labels          = { foo = "bar" }   # Example label for identification
    tags            = ["foo", "bar"]    # Example network tags
  }

  

  depends_on = [     # Ensures APIs and IAM roles are ready before cluster creation
    google_project_service.compute,
    google_project_service.container,
    google_project_iam_member.node_sa_storage_admin,
    google_project_iam_member.node_sa_instance_admin,
    google_project_iam_member.node_sa_log_writer,
    google_project_iam_member.node_sa_metric_writer
  ]
}

# ---- Fetch kubeconfig ----
# Once the cluster is created, this executes a local command to fetch the cluster credentials
# and configure kubectl to connect to the new GKE cluster.
resource "null_resource" "fetch_kubeconfig" {
  depends_on = [google_container_cluster.primary]

  provisioner "local-exec" {
    command = "gcloud container clusters get-credentials mtwa-cluster --zone us-central1-a --project ${var.project}"
  }
}

# ---- Static IP for Load Balancer ----
# Reserves a static external IP address that will be used later for the GitLab Ingress Load Balancer.
resource "google_compute_address" "gitlab_lb" {
  name         = "gitlab-nginx-lb-ip"
  region       = var.region
  address_type = "EXTERNAL"
  network_tier = "PREMIUM"   # High-performance global network tier
}

# ---- Save IP locally ----
# Writes the reserved Load Balancer IP address to a local text file (lb_ip.txt)
# so that it can be reused by other Terraform files.
resource "local_file" "lb_ip_txt" {
  content  = google_compute_address.gitlab_lb.address
  filename = "${path.module}/lb_ip.txt"
}
