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
}

# Variable for cluster configuration (derived from config file)
# This maintains backward compatibility with existing Terraform code
variable "cluster" {
  description = "Single cluster configuration (values loaded from config/homelab.yaml)"
  type = object({
    cluster_name          = string
    cluster_id            = number
    node_count            = number
    node_start_ip         = number
    cores                 = number
    cpu_type              = string
    memory                = number
    disk_size             = number
    vlan_id               = optional(number, null)
    subnet_prefix         = string
    gateway               = string
    dns_servers           = list(string)
    kube_vip              = string
    kube_vip_hostname     = string
    lb_cidrs              = string
    ssh_user              = string
    cert_manager_email    = string
    cert_manager_domain   = string
    cloudflare_email      = string
    default_cert_issuer   = optional(string, "letsencrypt-staging")
    traefik_dashboard_domain  = string
    longhorn_domain           = optional(string, null)
    longhorn_cert_issuer      = optional(string, null)
    argocd_domain             = string
    argocd_github_repo_url    = string
    grafana_domain            = string
    external_dns_domain       = string
    authentik_domain          = string
  })

  # Default values are loaded from config/homelab.yaml
  default = {
    cluster_name      = "homelab"               # Overridden by local.cluster.name
    cluster_id        = 1                       # Overridden by local.cluster.id
    node_count        = 1
    node_start_ip     = 20
    cores             = 4
    cpu_type          = "host"
    memory            = 12288
    disk_size         = 100
    vlan_id           = null
    subnet_prefix     = "192.168.10"
    gateway           = "192.168.10.1"
    dns_servers       = ["1.1.1.1", "1.0.0.1"]
    kube_vip          = "192.168.10.15"
    kube_vip_hostname = "homelab-api"
    lb_cidrs          = "192.168.10.150/28"
    ssh_user          = "ubuntu"
    cert_manager_email    = "hughlardner@gmail.com"
    cert_manager_domain   = "silverseekers.org"
    cloudflare_email      = "hughlardner@gmail.com"
    default_cert_issuer   = "letsencrypt-prod"
    traefik_dashboard_domain = "traefik.silverseekers.org"
    longhorn_domain          = "longhorn.silverseekers.org"
    argocd_domain            = "argocd.silverseekers.org"
    argocd_github_repo_url   = "https://github.com/HughLardner/homelab.git"
    grafana_domain           = "grafana.silverseekers.org"
    external_dns_domain      = "silverseekers.org"
    authentik_domain         = "auth.silverseekers.org"
  }
}

# Merged configuration - config file values take precedence
locals {
  # Create the cluster config by merging defaults with config file values
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
    authentik_domain         = local.services.authelia.domain
  }
}
