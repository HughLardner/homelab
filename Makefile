.PHONY: help init plan apply destroy ssh-* k3s-* metallb-* longhorn-* cert-manager-* traefik-* argocd-* monitoring-* sealed-secrets-* seal-secrets root-app-deploy apps-list apps-status monitoring-secrets inventory clean

# Default target
help:
	@echo "Homelab Infrastructure Makefile"
	@echo ""
	@echo "Terraform Commands:"
	@echo "  make init          - Initialize Terraform"
	@echo "  make plan          - Plan infrastructure changes"
	@echo "  make apply         - Apply infrastructure changes"
	@echo "  make destroy       - Destroy infrastructure"
	@echo "  make output        - Show Terraform outputs"
	@echo ""
	@echo "Ansible Commands:"
	@echo "  make inventory         - Generate Ansible inventory from Terraform"
	@echo "  make node-prep         - Prepare nodes (update packages, configure system)"
	@echo "  make node-prep-reboot  - Prepare nodes with auto-reboot after upgrade"
	@echo "  make k3s-install       - Install K3s cluster"
	@echo "  make k3s-status        - Check K3s cluster status"
	@echo "  make k3s-destroy       - Uninstall K3s from all nodes"
	@echo "  make metallb-install   - Install MetalLB (LoadBalancer)"
	@echo "  make metallb-test      - Install MetalLB with LoadBalancer testing"
	@echo "  make longhorn-install     - Install Longhorn (Storage)"
	@echo "  make longhorn-ui          - Open Longhorn UI"
	@echo "  make cert-manager-install - Install cert-manager (TLS)"
	@echo "  make cert-manager-status  - Check cert-manager status"
	@echo "  make traefik-install      - Install Traefik (Ingress Controller)"
	@echo "  make traefik-status       - Check Traefik status"
	@echo "  make traefik-dashboard    - Open Traefik dashboard"
	@echo "  make argocd-install       - Install ArgoCD (GitOps)"
	@echo "  make argocd-status        - Check ArgoCD status"
	@echo "  make argocd-password      - Get ArgoCD admin password"
	@echo "  make argocd-ui            - Open ArgoCD web UI"
	@echo "  make sealed-secrets-install - Install Sealed Secrets (Secret Encryption)"
	@echo "  make sealed-secrets-status  - Check Sealed Secrets status"
	@echo "  make seal-secrets           - Encrypt secrets from secrets.yml and commit to git"
	@echo ""
	@echo "ArgoCD GitOps Commands:"
	@echo "  make root-app-deploy       - Deploy App-of-Apps (manages all applications)"
	@echo "  make apps-list             - List all ArgoCD applications"
	@echo "  make apps-status           - Show status of all applications"
	@echo "  make monitoring-secrets    - Create monitoring Kubernetes secrets (prerequisite)"
	@echo "  make monitoring-deploy     - Deploy monitoring via ArgoCD (GitOps)"
	@echo "  make monitoring-sync       - Sync monitoring application"
	@echo "  make monitoring-install    - Install monitoring via Ansible (legacy)"
	@echo "  make monitoring-status     - Check monitoring stack status"
	@echo "  make grafana-ui            - Open Grafana dashboard"
	@echo "  make prometheus-ui         - Port-forward Prometheus UI"
	@echo "  make ping                 - Test connectivity to all nodes"
	@echo ""
	@echo "SSH Commands:"
	@echo "  make ssh-node1     - SSH to node 1"
	@echo "  make ssh-node2     - SSH to node 2"
	@echo "  make ssh-node3     - SSH to node 3"
	@echo ""
	@echo "Workspace Commands:"
	@echo "  make workspace-list    - List all workspaces"
	@echo "  make workspace-show    - Show current workspace"
	@echo "  make workspace WS=name - Switch to workspace"
	@echo ""
	@echo "Utility Commands:"
	@echo "  make clean         - Clean temporary files"
	@echo "  make logs          - Show Ansible logs"

# ============================================================================
# Terraform Commands
# ============================================================================

init:
	cd terraform && terraform init

plan:
	cd terraform && terraform plan

apply:
	cd terraform && terraform apply -auto-approve

destroy:
	cd terraform && terraform destroy -auto-approve

output:
	cd terraform && terraform output

# ============================================================================
# Workspace Management
# ============================================================================

workspace-list:
	cd terraform && terraform workspace list

workspace-show:
	cd terraform && terraform workspace show

workspace:
ifndef WS
	@echo "Error: WS variable not set. Usage: make workspace WS=<workspace-name>"
	@exit 1
endif
	cd terraform && terraform workspace select $(WS) || terraform workspace new $(WS)

# ============================================================================
# Ansible Commands
# ============================================================================

inventory:
	@echo "Generating Ansible inventory from Terraform..."
	@cd ansible/inventory && python3 generate_inventory.py --format yaml > hosts.yml
	@echo "✅ Inventory generated: ansible/inventory/hosts.yml"

node-prep: inventory
	@echo "Preparing nodes..."
	cd ansible && ansible-playbook playbooks/node-prep.yml

node-prep-reboot: inventory
	@echo "Preparing nodes (with reboot after upgrade)..."
	cd ansible && ansible-playbook playbooks/node-prep.yml \
	  -e node_prep_reboot_after_upgrade=true

k3s-install: inventory
	@echo "Installing K3s cluster..."
	cd ansible && ansible-playbook playbooks/k3s-cluster-setup.yml

k3s-status:
	cd ansible && ansible k3s_cluster -m shell -a "systemctl status k3s --no-pager"

k3s-destroy:
	@echo "⚠️  WARNING: This will uninstall K3s from all nodes!"
	@read -p "Are you sure? [y/N] " -n 1 -r; \
	echo; \
	if [[ $$REPLY =~ ^[Yy]$$ ]]; then \
		cd ansible && ansible k3s_cluster -m shell -a "/usr/local/bin/k3s-uninstall.sh" -b; \
	fi

metallb-install: inventory
	@echo "Installing MetalLB..."
	cd ansible && ansible-playbook playbooks/metallb.yml

metallb-test: inventory
	@echo "Installing MetalLB with LoadBalancer testing..."
	cd ansible && ansible-playbook playbooks/metallb.yml \
	  -e metallb_test_loadbalancer=true

longhorn-install: inventory
	@echo "Installing Longhorn storage..."
	cd ansible && ansible-playbook playbooks/longhorn.yml

longhorn-ui:
	@echo "Accessing Longhorn UI..."
	@LONGHORN_IP=$$(kubectl get svc -n longhorn-system longhorn-frontend -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo ""); \
	if [ -z "$$LONGHORN_IP" ]; then \
		echo "Longhorn UI not exposed via LoadBalancer. Use port-forward:"; \
		echo "  kubectl port-forward -n longhorn-system svc/longhorn-frontend 8080:80"; \
		echo "  Then open: http://localhost:8080"; \
	else \
		echo "Longhorn UI: http://$$LONGHORN_IP"; \
		open "http://$$LONGHORN_IP" 2>/dev/null || xdg-open "http://$$LONGHORN_IP" 2>/dev/null || echo "Open http://$$LONGHORN_IP in your browser"; \
	fi

cert-manager-install: inventory
	@echo "Installing cert-manager..."
	cd ansible && ansible-playbook playbooks/cert-manager.yml

cert-manager-status:
	@echo "Cert-Manager Status:"
	@echo ""
	@echo "Pods:"
	@kubectl get pods -n cert-manager
	@echo ""
	@echo "ClusterIssuers:"
	@kubectl get clusterissuer

traefik-install: inventory
	@echo "Installing Traefik ingress controller..."
	cd ansible && ansible-playbook playbooks/traefik.yml

traefik-status:
	@echo "Traefik Status:"
	@echo ""
	@echo "Pods:"
	@kubectl get pods -n traefik
	@echo ""
	@echo "Service:"
	@kubectl get svc -n traefik
	@echo ""
	@echo "IngressClass:"
	@kubectl get ingressclass
	@echo ""
	@echo "IngressRoutes:"
	@kubectl get ingressroute -A

traefik-dashboard:
	@echo "Accessing Traefik Dashboard..."
	@TRAEFIK_DOMAIN=$$(kubectl get ingressroute -n traefik traefik-dashboard -o jsonpath='{.spec.routes[0].match}' 2>/dev/null | grep -oP 'Host\(\K[^)]+' | tr -d '`' || echo ""); \
	if [ -z "$$TRAEFIK_DOMAIN" ]; then \
		echo "Dashboard IngressRoute not found. Use port-forward:"; \
		echo "  kubectl port-forward -n traefik svc/traefik 9000:9000"; \
		echo "  Then open: http://localhost:9000/dashboard/"; \
	else \
		echo "Traefik Dashboard: https://$$TRAEFIK_DOMAIN"; \
		open "https://$$TRAEFIK_DOMAIN" 2>/dev/null || xdg-open "https://$$TRAEFIK_DOMAIN" 2>/dev/null || echo "Open https://$$TRAEFIK_DOMAIN in your browser"; \
	fi

argocd-install: inventory
	@echo "Installing ArgoCD GitOps platform..."
	cd ansible && ansible-playbook playbooks/argocd.yml

argocd-status:
	@echo "ArgoCD Status:"
	@echo ""
	@echo "Pods:"
	@kubectl get pods -n argocd
	@echo ""
	@echo "Services:"
	@kubectl get svc -n argocd
	@echo ""
	@echo "IngressRoute:"
	@kubectl get ingressroute -n argocd
	@echo ""
	@echo "Applications:"
	@kubectl get applications -n argocd 2>/dev/null || echo "No applications found"

argocd-password:
	@echo "ArgoCD Admin Password:"
	@echo "(Password is set via Terraform configuration)"
	@echo ""
	@echo "If you need to reset the password, use:"
	@echo "  kubectl -n argocd patch secret argocd-secret -p '{\"stringData\": {\"admin.password\": \"<bcrypt-hash>\"}}'"

argocd-ui:
	@echo "Accessing ArgoCD Web UI..."
	@ARGOCD_DOMAIN=$$(kubectl get ingressroute -n argocd argocd-server -o jsonpath='{.spec.routes[0].match}' 2>/dev/null | grep -oP 'Host\(\K[^)]+' | tr -d '`' || echo ""); \
	if [ -z "$$ARGOCD_DOMAIN" ]; then \
		echo "IngressRoute not found. Use port-forward:"; \
		echo "  kubectl port-forward -n argocd svc/argocd-server 8080:80"; \
		echo "  Then open: http://localhost:8080"; \
	else \
		echo "ArgoCD UI: https://$$ARGOCD_DOMAIN"; \
		open "https://$$ARGOCD_DOMAIN" 2>/dev/null || xdg-open "https://$$ARGOCD_DOMAIN" 2>/dev/null || echo "Open https://$$ARGOCD_DOMAIN in your browser"; \
	fi

sealed-secrets-install: inventory
	@echo "Installing Sealed Secrets..."
	cd ansible && ansible-playbook playbooks/sealed-secrets.yml

sealed-secrets-status:
	@echo "Sealed Secrets Status:"
	@echo ""
	@echo "Pods:"
	@kubectl get pods -n kube-system -l app.kubernetes.io/name=sealed-secrets
	@echo ""
	@echo "Service:"
	@kubectl get svc -n kube-system sealed-secrets-controller
	@echo ""
	@echo "Sealing Keys:"
	@kubectl get secrets -n kube-system -l sealedsecrets.bitnami.com/sealed-secrets-key
	@echo ""
	@echo "💡 To install kubeseal CLI:"
	@echo "  macOS:  brew install kubeseal"
	@echo "  Linux:  See kubernetes/services/sealed-secrets/README.md"
	@echo ""
	@echo "📖 Documentation: kubernetes/services/sealed-secrets/README.md"

seal-secrets:
	@if [ ! -f secrets.yml ]; then \
		echo "❌ secrets.yml not found!"; \
		echo ""; \
		echo "Create it from the template:"; \
		echo "  cp secrets.example.yml secrets.yml"; \
		echo ""; \
		echo "Then fill in your secret values and run this command again."; \
		exit 1; \
	fi
	@echo "Sealing secrets from secrets.yml..."
	ansible-playbook ansible/playbooks/seal-secrets.yml

# ============================================================================
# ArgoCD GitOps Commands
# ============================================================================

root-app-deploy:
	@echo "Deploying App-of-Apps (root-app)..."
	kubectl apply -f kubernetes/applications/root-app.yaml
	@echo ""
	@echo "✅ Root app deployed!"
	@echo ""
	@echo "The root-app will automatically deploy all applications in kubernetes/applications/*/"
	@echo ""
	@echo "View applications:"
	@echo "  make apps-list"
	@echo "  make apps-status"

apps-list:
	@echo "ArgoCD Applications:"
	@echo ""
	@kubectl get applications -n argocd 2>/dev/null || echo "No applications found. Deploy root-app first: make root-app-deploy"

apps-status:
	@echo "ArgoCD Applications Status:"
	@echo ""
	@if command -v argocd >/dev/null 2>&1; then \
		argocd app list; \
	else \
		kubectl get applications -n argocd -o wide; \
	fi

monitoring-secrets: inventory
	@echo "Creating monitoring Kubernetes secrets..."
	cd ansible && ansible-playbook playbooks/monitoring-secrets.yml

monitoring-deploy:
	@echo "Deploying Monitoring Stack via ArgoCD..."
	kubectl apply -f kubernetes/applications/monitoring/application.yaml
	@echo ""
	@echo "✅ Monitoring application deployed!"
	@echo ""
	@echo "⚠️  IMPORTANT: Ensure secrets exist first:"
	@echo "  make monitoring-secrets"
	@echo ""
	@echo "Monitor sync status:"
	@echo "  make monitoring-sync"
	@echo "  make apps-status"
	@echo ""
	@echo "Or watch in ArgoCD UI:"
	@echo "  make argocd-ui"

monitoring-sync:
	@echo "Syncing monitoring application..."
	@if command -v argocd >/dev/null 2>&1; then \
		argocd app sync monitoring; \
		argocd app wait monitoring --health; \
	else \
		echo "ArgoCD CLI not installed. Install with:"; \
		echo "  brew install argocd"; \
		echo ""; \
		echo "Or manually sync via kubectl:"; \
		echo "  kubectl -n argocd patch app monitoring --type merge -p '{\"operation\":{\"initiatedBy\":{\"username\":\"admin\"},\"sync\":{\"revision\":\"HEAD\"}}}'"; \
	fi

monitoring-install: inventory
	@echo "Installing Monitoring Stack (Prometheus + Grafana)..."
	cd ansible && ansible-playbook playbooks/monitoring.yml

monitoring-status:
	@echo "Monitoring Stack Status:"
	@echo ""
	@echo "Pods:"
	@kubectl get pods -n monitoring
	@echo ""
	@echo "PVCs:"
	@kubectl get pvc -n monitoring
	@echo ""
	@echo "Services:"
	@kubectl get svc -n monitoring
	@echo ""
	@echo "IngressRoute:"
	@kubectl get ingressroute -n monitoring

grafana-ui:
	@echo "Accessing Grafana Dashboard..."
	@GRAFANA_DOMAIN=$$(kubectl get ingressroute -n monitoring grafana -o jsonpath='{.spec.routes[0].match}' 2>/dev/null | grep -oP 'Host\(\K[^)]+' | tr -d '`' || echo ""); \
	if [ -z "$$GRAFANA_DOMAIN" ]; then \
		echo "IngressRoute not found. Use port-forward:"; \
		echo "  kubectl port-forward -n monitoring svc/kube-prometheus-grafana 3000:80"; \
		echo "  Then open: http://localhost:3000"; \
	else \
		echo "Grafana: https://$$GRAFANA_DOMAIN"; \
		open "https://$$GRAFANA_DOMAIN" 2>/dev/null || xdg-open "https://$$GRAFANA_DOMAIN" 2>/dev/null || echo "Open https://$$GRAFANA_DOMAIN in your browser"; \
	fi

prometheus-ui:
	@echo "Port-forwarding Prometheus UI..."
	@echo "Prometheus will be available at: http://localhost:9090"
	kubectl port-forward -n monitoring svc/kube-prometheus-prometheus 9090:9090

ping:
	cd ansible && ansible all -m ping

# ============================================================================
# SSH Access
# ============================================================================

ssh-node1:
	ssh ubuntu@$$(cd terraform && terraform output -json | jq -r '.vm_ip_addresses.value[0]' | cut -d'/' -f1)

ssh-node2:
	ssh ubuntu@$$(cd terraform && terraform output -json | jq -r '.vm_ip_addresses.value[1]' | cut -d'/' -f1)

ssh-node3:
	ssh ubuntu@$$(cd terraform && terraform output -json | jq -r '.vm_ip_addresses.value[2]' | cut -d'/' -f1)

# ============================================================================
# Utility Commands
# ============================================================================

clean:
	find . -type d -name ".terraform" -exec rm -rf {} + 2>/dev/null || true
	find . -type f -name "*.tfstate.backup" -delete
	find . -type f -name ".DS_Store" -delete
	rm -f ansible/inventory/hosts.yml
	rm -rf ansible/.cache
	@echo "✅ Cleaned temporary files"

logs:
	@if [ -f ansible/logs/ansible.log ]; then \
		tail -f ansible/logs/ansible.log; \
	else \
		echo "No Ansible logs found"; \
	fi

# ============================================================================
# Quick Deploy (Full Stack)
# ============================================================================

deploy: apply inventory node-prep k3s-install
	@echo ""
	@echo "✅ Full deployment complete!"
	@echo ""
	@echo "Set kubeconfig:"
	@echo "  export KUBECONFIG=~/.kube/config-homelab"
	@echo ""
	@echo "Verify cluster:"
	@echo "  kubectl get nodes"
