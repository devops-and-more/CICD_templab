output "lb_ip" {
  value = local.lb_ip
}

output "gitlab_url" {
  value = "gitlab.${local.my_domain}"
}

