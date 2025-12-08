locals {
  proxmox_host   = "192.168.10.10"
  proxmox_node   = "proxmox01"
  template_vm_id = 9000

  # Generate list of nodes
  nodes = [
    for i in range(var.cluster.node_count) : {
      name       = "${var.cluster.cluster_name}-node-${i}"
      vm_id      = tonumber("${var.cluster.cluster_id}${var.cluster.node_start_ip + i}")
      ip_address = "${var.cluster.subnet_prefix}.${var.cluster.node_start_ip + i}"
      cores      = var.cluster.cores
      cpu_type   = var.cluster.cpu_type
      memory     = var.cluster.memory
      disk_size  = var.cluster.disk_size
    }
  ]
}

# Export cluster config for Ansible
resource "local_file" "cluster_config_json" {
  content = jsonencode({
    cluster_name      = var.cluster.cluster_name
    nodes             = local.nodes
    subnet_prefix     = var.cluster.subnet_prefix
    gateway           = var.cluster.gateway
    dns_servers       = var.cluster.dns_servers
    kube_vip          = var.cluster.kube_vip
    kube_vip_hostname = var.cluster.kube_vip_hostname
    lb_cidrs          = var.cluster.lb_cidrs
    ssh_user          = var.cluster.ssh_user
    # Cert-Manager configuration
    cert_manager_email    = var.cluster.cert_manager_email
    cert_manager_domain   = var.cluster.cert_manager_domain
    cloudflare_email      = var.cluster.cloudflare_email
    cloudflare_api_token  = var.cloudflare_api_token
    # Traefik configuration
    traefik_dashboard_domain   = var.cluster.traefik_dashboard_domain
    traefik_dashboard_password = var.traefik_dashboard_password
    # ArgoCD configuration
    argocd_domain   = var.cluster.argocd_domain
    argocd_password = var.argocd_password
    argocd_github_repo_url = var.cluster.argocd_github_repo_url
    argocd_github_token = var.github_token
    # Monitoring configuration
    grafana_domain = var.cluster.grafana_domain
    grafana_admin_password = var.grafana_admin_password
    # External-DNS configuration
    external_dns_domain = var.cluster.external_dns_domain
  })
  filename = "../ansible/tmp/${var.cluster.cluster_name}/cluster_config.json"
}
