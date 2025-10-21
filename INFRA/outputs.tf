output "cluster_name" {
  value = google_container_cluster.primary.name
}

output "lb_ip" {
  value = google_compute_address.gitlab_lb.address
}
