#!/usr/bin/env python3
"""
Generate Ansible inventory from Terraform cluster_config.json

This script generates a minimal inventory with only:
- Node hostnames and IP addresses (from Terraform)
- SSH connection settings

All other configuration is loaded from config/homelab.yaml via vars_files
in each playbook, ensuring a single source of truth.
"""

import json
import sys
from pathlib import Path


def generate_inventory(cluster_name="homelab"):
    """Generate Ansible inventory from Terraform output"""

    # Path to Terraform-generated cluster config
    config_path = Path(__file__).parent.parent / "tmp" / cluster_name / "cluster_config.json"

    if not config_path.exists():
        print(f"Error: Cluster config not found at {config_path}", file=sys.stderr)
        print("Run 'terraform apply' first to generate cluster configuration", file=sys.stderr)
        sys.exit(1)

    # Load cluster configuration
    with open(config_path) as f:
        config = json.load(f)

    # Build minimal inventory structure
    # All configuration vars now come from config/homelab.yaml via vars_files
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
                        # Only include infrastructure vars needed for K3s setup
                        # These are dynamic values from Terraform that can't be in config file
                        "k3s_cluster_name": config["cluster_name"],
                        "k3s_gateway": config["gateway"],
                        "k3s_dns_servers": config["dns_servers"],
                        "k3s_kube_vip": config.get("kube_vip", ""),
                        "k3s_kube_vip_hostname": config.get("kube_vip_hostname", ""),
                        "metallb_ipv4_pools": config.get("lb_cidrs", ""),
                        # Cloudflare token needed for cert-manager DNS challenge
                        "cloudflare_api_token": config.get("cloudflare_api_token", ""),
                    }
                }
            },
            "vars": {
                # SSH connection settings
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
