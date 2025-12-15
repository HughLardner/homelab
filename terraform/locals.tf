locals {
  proxmox_host   = "192.168.10.10"
  proxmox_node   = "proxmox01"
  template_vm_id = 9000

  # Generate list of nodes
  nodes = [
    for i in range(local.cluster_config.node_count) : {
      name       = "${local.cluster_config.cluster_name}-node-${i}"
      vm_id      = tonumber("${local.cluster_config.cluster_id}${local.cluster_config.node_start_ip + i}")
      ip_address = "${local.cluster_config.subnet_prefix}.${local.cluster_config.node_start_ip + i}"
      cores      = local.cluster_config.cores
      cpu_type   = local.cluster_config.cpu_type
      memory     = local.cluster_config.memory
      disk_size  = local.cluster_config.disk_size
    }
  ]
}

# Export cluster config for Ansible
resource "local_file" "cluster_config_json" {
  content = jsonencode({
    cluster_name      = local.cluster_config.cluster_name
    nodes             = local.nodes
    subnet_prefix     = local.cluster_config.subnet_prefix
    gateway           = local.cluster_config.gateway
    dns_servers       = local.cluster_config.dns_servers
    kube_vip          = local.cluster_config.kube_vip
    kube_vip_hostname = local.cluster_config.kube_vip_hostname
    lb_cidrs          = local.cluster_config.lb_cidrs
    ssh_user          = local.cluster_config.ssh_user
    # Cert-Manager configuration
    cert_manager_email    = local.cluster_config.cert_manager_email
    cert_manager_domain   = local.cluster_config.cert_manager_domain
    cloudflare_email      = local.cluster_config.cloudflare_email
    cloudflare_api_token  = var.cloudflare_api_token
    # TLS Issuer: "letsencrypt-staging" for testing, "letsencrypt-prod" for trusted certs
    default_cert_issuer   = local.cluster_config.default_cert_issuer
    # Traefik configuration
    traefik_dashboard_domain   = local.cluster_config.traefik_dashboard_domain
    traefik_dashboard_password = var.traefik_dashboard_password
    # ArgoCD configuration
    argocd_domain   = local.cluster_config.argocd_domain
    argocd_password = var.argocd_password
    argocd_github_repo_url = local.cluster_config.argocd_github_repo_url
    argocd_github_token = var.github_token
    # Monitoring configuration
    grafana_domain = local.cluster_config.grafana_domain
    grafana_admin_password = var.grafana_admin_password
    # External-DNS configuration
    external_dns_domain = local.cluster_config.external_dns_domain
    # Authentik SSO configuration
    authelia_domain = local.cluster_config.authelia_domain
    # Longhorn configuration
    longhorn_domain = local.cluster_config.longhorn_domain
  })
  filename = "../ansible/tmp/${local.cluster_config.cluster_name}/cluster_config.json"
}
