#!/usr/bin/env python3
"""
Generate Ansible inventory from Terraform cluster_config.json
This ensures inventory is always in sync with Terraform state
"""

import json
import sys
import os
from pathlib import Path

def generate_inventory(cluster_name="homelab"):
    """Generate Ansible inventory from Terraform output"""

    # Path to Terraform-generated cluster config
    config_path = Path(__file__).parent.parent / "tmp" / cluster_name / "cluster_config.json"

    if not config_path.exists():
        print(f"Error: Cluster config not found at {config_path}", file=sys.stderr)
        print(f"Run 'terraform apply' first to generate cluster configuration", file=sys.stderr)
        sys.exit(1)

    # Load cluster configuration
    with open(config_path) as f:
        config = json.load(f)

    # Build inventory structure
    inventory = {
        "all": {
            "children": {
                "k3s_cluster": {
                    "children": {
                        "k3s_masters": {
                            "hosts": {}
                        }
                    },
                    "vars": {
                        # Cluster-wide variables from Terraform
                        "k3s_cluster_name": config["cluster_name"],
                        "k3s_gateway": config["gateway"],
                        "k3s_dns_servers": config["dns_servers"],
                        "k3s_kube_vip": config.get("kube_vip", ""),
                        "k3s_kube_vip_hostname": config.get("kube_vip_hostname", ""),
                        "metallb_ipv4_pools": config.get("lb_cidrs", ""),
                        # Longhorn storage configuration (optional - has defaults)
                        # Single node = 1 replica, increase to 2 when adding second node
                        "longhorn_replica_count": config.get("longhorn_replica_count", 1),
                        "longhorn_data_path": config.get("longhorn_data_path", "/var/lib/longhorn"),
                        "longhorn_ui_service_type": config.get("longhorn_ui_service_type", "LoadBalancer"),
                        # Cert-Manager TLS configuration (required)
                        "cert_manager_email": config.get("cert_manager_email", ""),
                        "cert_manager_domain": config.get("cert_manager_domain", ""),
                        "cloudflare_email": config.get("cloudflare_email", ""),
                        "cloudflare_api_token": config.get("cloudflare_api_token", ""),
                        # Global TLS issuer - cascades to all services unless overridden
                        # Options: "letsencrypt-staging" (testing) or "letsencrypt-prod" (trusted)
                        "default_cert_issuer": config.get("default_cert_issuer", "letsencrypt-staging"),
                        # Traefik Ingress Controller configuration (optional - has defaults)
                        "traefik_replicas": config.get("traefik_replicas", 2),
                        "traefik_service_type": config.get("traefik_service_type", "LoadBalancer"),
                        "traefik_loadbalancer_ip": config.get("traefik_loadbalancer_ip", ""),
                        "traefik_storage_class": config.get("traefik_storage_class", "longhorn"),
                        "traefik_dashboard_domain": config.get("traefik_dashboard_domain", ""),
                        "traefik_cert_issuer": config.get("traefik_cert_issuer") or config.get("default_cert_issuer", "letsencrypt-staging"),
                        "traefik_dashboard_username": config.get("traefik_dashboard_username", "admin"),
                        "traefik_dashboard_password": config.get("traefik_dashboard_password", ""),
                        # ArgoCD GitOps configuration
                        "argocd_domain": config.get("argocd_domain", ""),
                        "argocd_password": config.get("argocd_password", ""),
                        "argocd_replicas": config.get("argocd_replicas", 1),
                        "argocd_cert_issuer": config.get("argocd_cert_issuer") or config.get("default_cert_issuer", "letsencrypt-staging"),
                        "argocd_github_repo_url": config.get("argocd_github_repo_url", ""),
                        "argocd_github_token": config.get("argocd_github_token", ""),
                        # Monitoring configuration
                        "grafana_domain": config.get("grafana_domain", ""),
                        "grafana_admin_password": config.get("grafana_admin_password", ""),
                        "grafana_cert_issuer": config.get("grafana_cert_issuer") or config.get("default_cert_issuer", "letsencrypt-staging"),
                        "monitoring_storage_class": config.get("monitoring_storage_class", "longhorn"),
                        "prometheus_storage_size": config.get("prometheus_storage_size", "10Gi"),
                        "prometheus_retention": config.get("prometheus_retention", "15d"),
                        "grafana_storage_size": config.get("grafana_storage_size", "5Gi"),
                        "alertmanager_storage_size": config.get("alertmanager_storage_size", "2Gi"),
                        # External-DNS configuration
                        "external_dns_domain": config.get("external_dns_domain", "silverseekers.org"),
                        # Authentik SSO configuration
                        "authentik_domain": config.get("authentik_domain", "auth.silverseekers.org"),
                        "authentik_storage_class": config.get("authentik_storage_class", "longhorn"),
                        "authentik_cert_issuer": config.get("authentik_cert_issuer") or config.get("default_cert_issuer", "letsencrypt-staging"),
                        # Longhorn configuration
                        "longhorn_domain": config.get("longhorn_domain", ""),
                        "longhorn_cert_issuer": config.get("longhorn_cert_issuer") or config.get("default_cert_issuer", "letsencrypt-staging")
                    }
                }
            },
            "vars": {
                "ansible_user": config.get("ssh_user", "ubuntu"),
                "ansible_ssh_private_key_file": "~/.ssh/id_ed25519_personal",
                "ansible_ssh_common_args": "-o StrictHostKeyChecking=no",
                "ansible_python_interpreter": "/usr/bin/python3"
            }
        }
    }

    # Add each node to k3s_masters group
    for idx, node in enumerate(config["nodes"]):
        # Extract IP without CIDR notation
        ip_address = node["ip_address"].split("/")[0]

        inventory["all"]["children"]["k3s_cluster"]["children"]["k3s_masters"]["hosts"][node["name"]] = {
            "ansible_host": ip_address,
            "node_index": idx + 1,
            "node_role": "master"
        }

    return inventory


def main():
    """Main entry point"""
    import argparse

    parser = argparse.ArgumentParser(description="Generate Ansible inventory from Terraform")
    parser.add_argument("--cluster", default="homelab", help="Cluster name (default: homelab)")
    parser.add_argument("--format", choices=["json", "yaml"], default="yaml", help="Output format")
    args = parser.parse_args()

    inventory = generate_inventory(args.cluster)

    if args.format == "json":
        print(json.dumps(inventory, indent=2))
    else:
        # Output as YAML
        import yaml
        print(yaml.dump(inventory, default_flow_style=False, sort_keys=False))


if __name__ == "__main__":
    main()
