# Create a resource pool for the cluster
resource "proxmox_virtual_environment_pool" "operations_pool" {
  comment = "Managed by Terraform"
  pool_id = upper(local.cluster_config.cluster_name)
}
