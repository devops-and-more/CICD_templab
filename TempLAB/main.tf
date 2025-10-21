# -------------------------------
# AWS Backend Resources (S3 + DynamoDB)
# -------------------------------

locals {
  aws_creds = jsondecode(file("${path.module}/../aws_credentials.json"))
}

resource "aws_s3_bucket" "tf_state_bucket" {
  bucket        = "templab-terraform-state-bucket-072310"
  force_destroy = true
  tags = {
    Name        = "templab"
    Environment = "test"
  }
}

resource "aws_s3_bucket_versioning" "versioning" {
  bucket = aws_s3_bucket.tf_state_bucket.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "encryption" {
  bucket = aws_s3_bucket.tf_state_bucket.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_dynamodb_table" "tf_state_lock" {
  name         = "terraform-lock-table"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  tags = {
    Name        = "TerraformLockTable"
    Environment = "Dev"
  }
}

# -------------------------------
# Kubernetes Storage + Namespace
# -------------------------------

resource "kubernetes_storage_class" "pd_balanced" {
  metadata { name = "pd-balanced" }
  storage_provisioner    = "pd.csi.storage.gke.io"
  parameters             = { type = "pd-balanced" }
  reclaim_policy         = "Delete"
  volume_binding_mode    = "WaitForFirstConsumer"
  allow_volume_expansion = true
}

resource "kubernetes_namespace" "gitlab" {
  metadata { name = "gitlab" }
}

resource "kubernetes_secret" "gitlab_initial_root" {
  depends_on = [
    kubernetes_namespace.gitlab,
    kubernetes_storage_class.pd_balanced
  ]
  metadata {
    name      = "gitlab-gitlab-initial-root-password"
    namespace = kubernetes_namespace.gitlab.metadata[0].name
  }
  data = {
    password = "D£v0p$&+"
  }
  type = "Opaque"

  lifecycle {
    ignore_changes = [metadata[0].labels]
  }
}

# -------------------------------
# Read IP from previous infra (GCP)
# -------------------------------
data "local_file" "lb_ip" {
  filename = abspath("${path.module}/../INFRA/lb_ip.txt")
}

locals {
  lb_ip     = trimspace(data.local_file.lb_ip.content)
  my_domain = "${local.lb_ip}.nip.io"
}

# -------------------------------
# Helm: GitLab
# -------------------------------

resource "helm_release" "gitlab" {
  name             = "gitlab"
  repository       = "https://charts.gitlab.io"
  chart            = "gitlab"
  namespace        = kubernetes_namespace.gitlab.metadata[0].name
  create_namespace = true
  timeout          = 600
  wait             = false
  atomic           = false

  set = [
    { name = "global.hosts.domain", value = local.my_domain },
    { name = "global.hosts.externalIP", value = local.lb_ip },
    { name = "global.ingress.configureCertmanager", value = "true" },
    { name = "certmanager-issuer.email", value = var.acme_email },
    { name = "nginx-ingress.enabled", value = "true" },
    { name = "ingress.class", value = "gitlab-nginx" },
    { name = "global.ingress.tls.enabled", value = "true" },
    { name = "gitlab.webservice.ingress.tls.secretName", value = "gitlab-tls" },
    { name = "registry.ingress.tls.secretName", value = "gitlab-registry-tls" },
    { name = "minio.ingress.tls.secretName", value = "gitlab-minio-tls" },
    { name = "gitlab.kas.ingress.tls.secretName", value = "gitlab-kas-tls" },
    { name = "gitlab.webservice.minReplicas", value = "1" },
    { name = "gitlab.webservice.maxReplicas", value = "1" },
    { name = "gitlab.webservice.resources.requests.cpu", value = "200m" },
    { name = "gitlab.webservice.resources.requests.memory", value = "1024Mi" },
    { name = "gitlab.sidekiq.resources.requests.memory", value = "512Mi" },
    { name = "postgresql.persistence.size", value = "10Gi" },
    { name = "gitlab.gitaly.persistence.size", value = "10Gi" },
    { name = "minio.persistence.size", value = "10Gi" }
  ]
}

# -------------------------------
# Helm: Grafana
# -------------------------------

resource "helm_release" "grafana" {
  name       = "grafana"
  repository = "https://grafana.github.io/helm-charts"
  chart      = "grafana"
  namespace  = kubernetes_namespace.gitlab.metadata[0].name

  values = [
    templatefile("${path.module}/grafana-values.yaml", {
      myDomain = local.my_domain
    })
  ]
}

