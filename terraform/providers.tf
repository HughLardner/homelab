terraform {
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "0.73.1"
    }
  }
}

provider "proxmox" {
  endpoint  = "https://${local.proxmox_host}:8006/api2/json"
  api_token = var.proxmox_api_token
  ssh {
    username = var.proxmox_username
    agent    = true
  }
  insecure = true
}
