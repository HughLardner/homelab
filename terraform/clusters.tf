# Simplified single-cluster configuration for homelab
variable "cluster" {
  description = "Single cluster configuration"
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
    ssh_user                  = string
    cert_manager_email        = string
    cert_manager_domain       = string
    cloudflare_email          = string
    # TLS Certificate Issuer - Controls staging vs production certs globally
    # Options: "letsencrypt-staging" (testing) or "letsencrypt-prod" (trusted certs)
    default_cert_issuer       = optional(string, "letsencrypt-staging")
    traefik_dashboard_domain  = string
    longhorn_domain           = optional(string, null)           # Optional, not used by default
    longhorn_cert_issuer      = optional(string, null)           # Falls back to default_cert_issuer
    # ArgoCD configuration
    argocd_domain             = string
    argocd_github_repo_url    = string
    # Monitoring configuration
    grafana_domain            = string
    external_dns_domain       = string
    # Authentik SSO configuration
    authentik_domain          = string
  })

  default = {
    cluster_name      = "homelab"
    cluster_id        = 1
    node_count        = 1           # Single node cluster (saves 8GB RAM on Proxmox)
    node_start_ip     = 20
    cores             = 4           # 4 cores for single node (plenty for homelab)
    cpu_type          = "host"      # Use host CPU for best performance
    memory            = 12288       # 12GB for single node (leaves ~3GB for Proxmox)
    disk_size         = 100         # 100GB disk (more space for local-path storage)
    vlan_id           = null        # No VLAN tag - handled by Unifi switch port
    subnet_prefix     = "192.168.10"
    gateway           = "192.168.10.1"
    dns_servers       = ["1.1.1.1", "1.0.0.1"]
    kube_vip          = "192.168.10.15"
    kube_vip_hostname = "homelab-api"
    lb_cidrs          = "192.168.10.150/28"
    ssh_user                   = "ubuntu"
    cert_manager_email         = "hughlardner@gmail.com"
    cert_manager_domain        = "silverseekers.org"
    cloudflare_email           = "hughlardner@gmail.com"
    # TLS Issuer: "letsencrypt-staging" for testing, "letsencrypt-prod" for trusted certs
    default_cert_issuer        = "letsencrypt-staging"
    traefik_dashboard_domain   = "traefik.silverseekers.org"
    longhorn_domain            = "longhorn.silverseekers.org"
    # ArgoCD GitOps
    argocd_domain   = "argocd.silverseekers.org"
    argocd_github_repo_url = "https://github.com/HughLardner/homelab.git"
    # Monitoring
    grafana_domain = "grafana.silverseekers.org"
    external_dns_domain = "silverseekers.org"
    # Authentik SSO
    authentik_domain = "auth.silverseekers.org"
  }
}


