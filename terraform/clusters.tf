# Cluster configuration loaded from config/homelab.yaml
# This ensures Terraform, Ansible, Helm, and ArgoCD all use the same values

locals {
  # Load configuration from the central config file
  config = yamldecode(file("${path.module}/../config/homelab.yaml"))

  # Convenience aliases for commonly used config sections
  cluster        = local.config.cluster
  infrastructure = local.config.infrastructure
  global         = local.config.global
  services       = local.config.services

  # Derived cluster configuration for backward compatibility with existing Terraform code
  # All values come directly from config/homelab.yaml - no defaults here
  cluster_config = {
    cluster_name          = local.cluster.name
    cluster_id            = local.cluster.id
    node_count            = local.infrastructure.node_count
    node_start_ip         = local.infrastructure.node_start_ip
    cores                 = local.infrastructure.cores
    cpu_type              = local.infrastructure.cpu_type
    memory                = local.infrastructure.memory
    disk_size             = local.infrastructure.disk_size
    vlan_id               = local.infrastructure.vlan_id
    subnet_prefix         = local.infrastructure.subnet_prefix
    gateway               = local.infrastructure.gateway
    dns_servers           = local.infrastructure.dns_servers
    kube_vip              = local.infrastructure.kube_vip
    kube_vip_hostname     = local.infrastructure.kube_vip_hostname
    lb_cidrs              = local.infrastructure.lb_cidrs
    ssh_user              = local.infrastructure.ssh_user
    cert_manager_email    = local.global.email
    cert_manager_domain   = local.global.domain
    cloudflare_email      = local.global.cloudflare_email
    default_cert_issuer   = local.global.cert_issuer
    traefik_dashboard_domain = local.services.traefik.domain
    longhorn_domain          = local.services.longhorn.domain
    argocd_domain            = local.services.argocd.domain
    argocd_github_repo_url   = local.services.argocd.github_repo_url
    grafana_domain           = local.services.grafana.domain
    external_dns_domain      = local.services.external_dns.domain
    authelia_domain          = local.services.authelia.domain
  }
}
