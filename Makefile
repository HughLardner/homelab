.PHONY: help init plan apply destroy ssh-node k3s-* metallb-* longhorn-* cert-manager-* certs-* traefik-* argocd-* authelia-* monitoring-* sealed-secrets-* seal-secrets kured-* root-app-deploy apps-list apps-status monitoring-secrets inventory clean clean-backups deploy-infra deploy-platform deploy-services deploy-all deploy deploy-apps rebuild

# Default target
help:
	@echo "Homelab Infrastructure Makefile"
	@echo ""
	@echo "Single-Node K3s Cluster (12GB RAM, Longhorn + local-path storage)"
	@echo ""
	@echo "═══════════════════════════════════════════════════════════════════"
	@echo "  TERRAFORM (Infrastructure)"
	@echo "═══════════════════════════════════════════════════════════════════"
	@echo "  make init              - Initialize Terraform"
	@echo "  make plan              - Plan infrastructure changes"
	@echo "  make apply             - Apply infrastructure changes"
	@echo "  make destroy           - Destroy infrastructure"
	@echo "  make output            - Show Terraform outputs"
	@echo ""
	@echo "═══════════════════════════════════════════════════════════════════"
	@echo "  LAYER 0: Cluster Bootstrap"
	@echo "═══════════════════════════════════════════════════════════════════"
	@echo "  make inventory         - Generate Ansible inventory from Terraform"
	@echo "  make node-prep         - Prepare nodes (update packages, configure system)"
	@echo "  make node-prep-reboot  - Prepare nodes with auto-reboot after upgrade"
	@echo "  make k3s-install       - Install K3s cluster"
	@echo "  make k3s-status        - Check K3s cluster status"
	@echo "  make k3s-destroy       - Uninstall K3s from all nodes"
	@echo "  make ping              - Test connectivity to all nodes"
	@echo ""
	@echo "═══════════════════════════════════════════════════════════════════"
	@echo "  LAYER 1: Foundation (no dependencies)"
	@echo "═══════════════════════════════════════════════════════════════════"
	@echo "  make metallb-install       - Install MetalLB (LoadBalancer provider)"
	@echo "  make metallb-test          - Install MetalLB with LoadBalancer testing"
	@echo "  make longhorn-install      - Install Longhorn (Distributed Storage)"
	@echo "  make longhorn-status       - Check Longhorn status"
	@echo "  make longhorn-ui           - Open Longhorn UI"
	@echo ""
	@echo "═══════════════════════════════════════════════════════════════════"
	@echo "  LAYER 2: Secrets Infrastructure"
	@echo "═══════════════════════════════════════════════════════════════════"
	@echo "  make sealed-secrets-install  - Install Sealed Secrets controller"
	@echo "  make sealed-secrets-status   - Check Sealed Secrets status"
	@echo "  make seal-secrets            - Encrypt secrets from secrets.yml"
	@echo ""
	@echo "═══════════════════════════════════════════════════════════════════"
	@echo "  LAYER 3: Platform Services (need Layer 1-2)"
	@echo "═══════════════════════════════════════════════════════════════════"
	@echo "  make cert-manager-install   - Install cert-manager (TLS certificates)"
	@echo "  make cert-manager-status    - Check cert-manager status"
	@echo "  make traefik-install        - Install Traefik (Ingress Controller)"
	@echo "  make traefik-status         - Check Traefik status"
	@echo "  make traefik-dashboard      - Open Traefik dashboard"
	@echo "  make longhorn-ingress       - Configure Longhorn IngressRoute (after Traefik)"
	@echo ""
	@echo "═══════════════════════════════════════════════════════════════════"
	@echo "  LAYER 4: GitOps & Identity (need Layer 1-3)"
	@echo "═══════════════════════════════════════════════════════════════════"
	@echo "  make argocd-install         - Install ArgoCD (GitOps)"
	@echo "  make argocd-status          - Check ArgoCD status"
	@echo "  make argocd-password        - Get ArgoCD admin password"
	@echo "  make argocd-ui              - Open ArgoCD web UI"
	@echo "  make authelia-secrets       - Apply Authelia sealed secrets (prerequisite)"
	@echo "  make authelia-install       - Install Authelia SSO Platform"
	@echo "  make authelia-status        - Check Authelia status"
	@echo "  make authelia-ui            - Open Authelia SSO UI"
	@echo "  make authelia-logs          - View Authelia logs"
	@echo ""
	@echo "═══════════════════════════════════════════════════════════════════"
	@echo "  LAYER 5: Applications (deployed via ArgoCD)"
	@echo "═══════════════════════════════════════════════════════════════════"
	@echo "  make root-app-deploy        - Deploy App-of-Apps (manages all applications)"
	@echo "  make apps-list              - List all ArgoCD applications"
	@echo "  make apps-status            - Show status of all applications"
	@echo "  make monitoring-secrets     - Create monitoring Kubernetes secrets"
	@echo "  make monitoring-deploy      - Deploy monitoring via ArgoCD"
	@echo "  make monitoring-sync        - Sync monitoring application"
	@echo "  make monitoring-status      - Check monitoring stack status"
	@echo "  make kured-deploy           - Deploy Kured (Automated Node Reboots)"
	@echo "  make kured-status           - Check Kured status"
	@echo "  make kured-logs             - View Kured logs"
	@echo ""
	@echo "═══════════════════════════════════════════════════════════════════"
	@echo "  Grafana & Monitoring UI"
	@echo "═══════════════════════════════════════════════════════════════════"
	@echo "  make grafana-ui             - Open Grafana dashboard"
	@echo "  make grafana-mcp-token      - Get Grafana MCP service account token"
	@echo "  make grafana-mcp-configure  - Auto-configure .cursor/mcp.json"
	@echo "  make grafana-mcp-regenerate - Regenerate the Grafana MCP token"
	@echo "  make vmsingle-ui            - Port-forward Victoria Metrics UI"
	@echo ""
	@echo "═══════════════════════════════════════════════════════════════════"
	@echo "  Backup & Restore"
	@echo "═══════════════════════════════════════════════════════════════════"
	@echo "  make certs-backup           - Backup Let's Encrypt certs (avoid rate limits)"
	@echo "  make certs-restore          - Restore Let's Encrypt certs from backup"
	@echo "  make certs-list             - List certificates and backup status"
	@echo "  make sealed-secrets-backup  - Backup encryption keys (before rebuild)"
	@echo "  make sealed-secrets-restore - Restore encryption keys (after rebuild)"
	@echo ""
	@echo "═══════════════════════════════════════════════════════════════════"
	@echo "  Full Stack Deployment"
	@echo "═══════════════════════════════════════════════════════════════════"
	@echo "  make deploy-infra      - Deploy infrastructure only (Terraform VMs)"
	@echo "  make deploy-platform   - Deploy infrastructure + K3s cluster"
	@echo "  make deploy-bootstrap  - Deploy minimal bootstrap (MetalLB, Longhorn, Sealed Secrets, ArgoCD)"
	@echo "  make deploy-services   - Deploy all services via ArgoCD (after bootstrap)"
	@echo "  make deploy-all        - Deploy everything (infra + platform + bootstrap + services)"
	@echo "  make deploy            - Alias for deploy-all (most common)"
	@echo "  make deploy-apps       - Deploy only applications (assumes services exist)"
	@echo "  make rebuild           - 🔥 NUKE & REBUILD: destroy everything and redeploy from scratch"
	@echo ""
	@echo "═══════════════════════════════════════════════════════════════════"
	@echo "  Utility Commands"
	@echo "═══════════════════════════════════════════════════════════════════"
	@echo "  make ssh-node          - SSH to the K3s node"
	@echo "  make workspace-list    - List all Terraform workspaces"
	@echo "  make workspace-show    - Show current workspace"
	@echo "  make workspace WS=name - Switch to workspace"
	@echo "  make clean             - Clean temporary files"
	@echo "  make clean-backups     - Remove cert and sealed-secrets backups"
	@echo "  make logs              - Show Ansible logs"

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
	@echo "========================================"
	@echo "🔐 Backing up secrets before destroy..."
	@echo "========================================"
	@# Backup certs if cluster is accessible
	@if kubectl cluster-info >/dev/null 2>&1; then \
		echo "Backing up TLS certificates..."; \
		$(MAKE) certs-backup || echo "⚠️  Cert backup failed (cluster may not have certs)"; \
		echo ""; \
		echo "Backing up Sealed Secrets keys..."; \
		$(MAKE) sealed-secrets-backup || echo "⚠️  Sealed secrets backup failed (may not be installed)"; \
		echo ""; \
	else \
		echo "⚠️  Cluster not accessible - skipping backups"; \
		echo ""; \
	fi
	@echo "========================================"
	@echo "🗑️  Destroying infrastructure..."
	@echo "========================================"
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
	@echo "Installing Longhorn distributed storage..."
	cd ansible && ansible-playbook playbooks/longhorn.yml

longhorn-status:
	@echo "Longhorn Status:"
	@echo ""
	@echo "Pods:"
	@kubectl get pods -n longhorn-system
	@echo ""
	@echo "Volumes:"
	@kubectl get volumes.longhorn.io -n longhorn-system
	@echo ""
	@echo "StorageClass:"
	@kubectl get storageclass longhorn

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

# Configure Longhorn IngressRoute (requires Traefik + cert-manager)
# Run after traefik-install to enable https://longhorn.silverseekers.org
longhorn-ingress: inventory
	@echo "Configuring Longhorn IngressRoute..."
	cd ansible && ansible-playbook playbooks/longhorn.yml

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

# ============================================================================
# Let's Encrypt Certificate Backup/Restore
# Preserves production certs to avoid rate limits during development
# ============================================================================

certs-backup:
	@echo "Backing up Let's Encrypt certificates..."
	@echo "This preserves certs locally to avoid rate limits during cluster rebuilds."
	@echo ""
	cd ansible && ansible-playbook playbooks/letsencrypt-certs.yml -e cert_action=backup

certs-restore:
	@echo "Restoring Let's Encrypt certificates from backup..."
	@echo ""
	cd ansible && ansible-playbook playbooks/letsencrypt-certs.yml -e cert_action=restore
	@echo ""
	@echo "Note: Run this AFTER cert-manager-install but BEFORE services request new certs."

certs-list:
	@echo "Certificate Status:"
	@echo ""
	cd ansible && ansible-playbook playbooks/letsencrypt-certs.yml -e cert_action=list
	@echo ""
	@echo "Local backup file:"
	@ls -la letsencrypt-certs-backup.yaml 2>/dev/null || echo "  No backup found. Run 'make certs-backup' to create one."

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
	@TRAEFIK_DOMAIN=$$(kubectl get ingressroute -n traefik traefik-dashboard -o jsonpath='{.spec.routes[0].match}' 2>/dev/null | sed 's/.*Host(`\([^`]*\)`).*/\1/' || echo ""); \
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
	@ARGOCD_DOMAIN=$$(kubectl get ingressroute -n argocd argocd-server -o jsonpath='{.spec.routes[0].match}' 2>/dev/null | sed 's/.*Host(`\([^`]*\)`).*/\1/' || echo ""); \
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

sealed-secrets-backup:
	@echo "Backing up Sealed Secrets encryption keys..."
	@echo "This preserves keys so existing sealed secrets remain decryptable after cluster rebuilds."
	@echo ""
	cd ansible && ansible-playbook playbooks/sealed-secrets-key.yml -e key_action=backup

sealed-secrets-restore:
	@echo "Restoring Sealed Secrets encryption keys from backup..."
	@echo "Run this BEFORE sealed-secrets-install to preserve existing sealed secrets."
	@echo ""
	cd ansible && ansible-playbook playbooks/sealed-secrets-key.yml -e key_action=restore

sealed-secrets-list:
	@echo "Sealed Secrets Key Status:"
	@echo ""
	cd ansible && ansible-playbook playbooks/sealed-secrets-key.yml -e key_action=list

seal-secrets:
	@if [ ! -f config/secrets.yml ]; then \
		echo "❌ config/secrets.yml not found!"; \
		echo ""; \
		echo "Create it from the template:"; \
		echo "  cp secrets.example.yml config/secrets.yml"; \
		echo ""; \
		echo "Then fill in your secret values and run this command again."; \
		exit 1; \
	fi
	@echo "Sealing secrets from config/secrets.yml..."
	ansible-playbook ansible/playbooks/seal-secrets.yml

authelia-secrets: inventory
	@echo "Creating Authelia Kubernetes secrets..."
	cd ansible && ansible-playbook playbooks/authelia-secrets.yml

authelia-install: inventory
	@echo "Installing Authelia SSO Platform..."
	cd ansible && ansible-playbook playbooks/authelia.yml

authelia-status:
	@echo "Authelia Status:"
	@echo ""
	@echo "Pods:"
	@kubectl get pods -n authelia
	@echo ""
	@echo "Services:"
	@kubectl get svc -n authelia
	@echo ""
	@echo "PVCs:"
	@kubectl get pvc -n authelia
	@echo ""
	@echo "IngressRoute:"
	@kubectl get ingressroute -n authelia
	@echo ""
	@echo "Middleware:"
	@kubectl get middleware -n authelia
	@echo ""
	@echo "Certificate:"
	@kubectl get certificate -n authelia

authelia-ui:
	@echo "Accessing Authelia SSO..."
	@AUTHELIA_DOMAIN=$$(kubectl get ingressroute -n authelia authelia -o jsonpath='{.spec.routes[0].match}' 2>/dev/null | sed 's/.*Host(`\([^`]*\)`).*/\1/' || echo ""); \
	if [ -z "$$AUTHELIA_DOMAIN" ]; then \
		echo "IngressRoute not found. Use port-forward:"; \
		echo "  kubectl port-forward -n authelia svc/authelia 9091:9091"; \
		echo "  Then open: http://localhost:9091"; \
	else \
		echo "Authelia: https://$$AUTHELIA_DOMAIN"; \
		open "https://$$AUTHELIA_DOMAIN" 2>/dev/null || xdg-open "https://$$AUTHELIA_DOMAIN" 2>/dev/null || echo "Open https://$$AUTHELIA_DOMAIN in your browser"; \
	fi

authelia-logs:
	@echo "Authelia Logs (Press Ctrl+C to exit):"
	kubectl logs -n authelia -l app.kubernetes.io/name=authelia -f --tail=50

kured-deploy:
	@echo "Deploying Kured via ArgoCD..."
	kubectl apply -f kubernetes/applications/kured/application.yaml
	@echo ""
	@echo "✅ Kured application deployed!"
	@echo ""
	@echo "Monitor sync status:"
	@echo "  make apps-status"
	@echo "  make kured-status"
	@echo ""
	@echo "💡 Maintenance Window: 04:00-08:00 UTC"
	@echo "📖 Documentation: kubernetes/services/kured/README.md"

kured-status:
	@echo "Kured Status:"
	@echo ""
	@echo "DaemonSet:"
	@kubectl get daemonset -n kube-system kured
	@echo ""
	@echo "Pods:"
	@kubectl get pods -n kube-system -l app.kubernetes.io/name=kured
	@echo ""
	@echo "Configuration:"
	@kubectl get daemonset -n kube-system kured -o jsonpath='{.spec.template.spec.containers[0].command}' | tr ',' '\n'
	@echo ""
	@echo ""
	@echo "Pending Reboots:"
	@kubectl get nodes -o custom-columns=NAME:.metadata.name,REBOOT:.metadata.annotations.weave\.works/kured-reboot-in-progress 2>/dev/null || echo "No pending reboots"
	@echo ""
	@echo "💡 Maintenance Window: 04:00-08:00 UTC"
	@echo "📖 Documentation: kubernetes/services/kured/README.md"

kured-logs:
	@echo "Kured Logs (Press Ctrl+C to exit):"
	kubectl logs -n kube-system -l app.kubernetes.io/name=kured -f --tail=50

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

monitoring-install:
	@echo "════════════════════════════════════════════════════════════════════"
	@echo "⚠️  DEPRECATED: monitoring-install (Ansible) is no longer supported"
	@echo "════════════════════════════════════════════════════════════════════"
	@echo ""
	@echo "Use ArgoCD-based deployment instead:"
	@echo ""
	@echo "  1. Create secrets:  make monitoring-secrets"
	@echo "  2. Deploy via ArgoCD:  make monitoring-deploy"
	@echo "  3. Sync if needed:  make monitoring-sync"
	@echo ""
	@echo "This ensures GitOps-managed, declarative monitoring deployment."
	@echo ""
	@exit 1

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
	@GRAFANA_DOMAIN=$$(kubectl get ingressroute -n monitoring grafana -o jsonpath='{.spec.routes[0].match}' 2>/dev/null | sed 's/.*Host(`\([^`]*\)`).*/\1/' || echo ""); \
	if [ -z "$$GRAFANA_DOMAIN" ]; then \
		echo "IngressRoute not found. Use port-forward:"; \
		echo "  kubectl port-forward -n monitoring svc/grafana 3000:80"; \
		echo "  Then open: http://localhost:3000"; \
	else \
		echo "Grafana: https://$$GRAFANA_DOMAIN"; \
		open "https://$$GRAFANA_DOMAIN" 2>/dev/null || xdg-open "https://$$GRAFANA_DOMAIN" 2>/dev/null || echo "Open https://$$GRAFANA_DOMAIN in your browser"; \
	fi

# Get Grafana MCP token from k8s Job logs or cached file
grafana-mcp-token:
	@echo "Fetching Grafana MCP service account token..."
	@TOKEN_FILE="$$HOME/.grafana-mcp-token"; \
	TOKEN=$$(kubectl logs -n monitoring job/grafana-mcp-setup 2>/dev/null | grep -o 'glsa_[a-zA-Z0-9_]*'); \
	if [ -n "$$TOKEN" ]; then \
		echo "$$TOKEN" > "$$TOKEN_FILE"; \
		echo "✅ Token found and cached to $$TOKEN_FILE"; \
	elif [ -f "$$TOKEN_FILE" ]; then \
		TOKEN=$$(cat "$$TOKEN_FILE"); \
		echo "✅ Using cached token from $$TOKEN_FILE"; \
	fi; \
	if [ -z "$$TOKEN" ]; then \
		echo "❌ Token not found."; \
		echo ""; \
		echo "Options:"; \
		echo "  1. If service account exists, delete it and re-sync:"; \
		echo "     - Go to https://grafana.silverseekers.org/admin/serviceaccounts"; \
		echo "     - Delete 'mcp-grafana' service account"; \
		echo "     - Run: make grafana-mcp-regenerate"; \
		echo ""; \
		echo "  2. If this is a fresh install, trigger ArgoCD sync:"; \
		echo "     kubectl patch application monitoring -n argocd --type merge -p '{\"operation\":{\"sync\":{}}}'"; \
		exit 1; \
	else \
		echo ""; \
		echo "Token: $$TOKEN"; \
		echo ""; \
		echo "To configure Cursor MCP, run:"; \
		echo "  make grafana-mcp-configure"; \
	fi

# Regenerate Grafana MCP token (deletes SA and re-syncs)
grafana-mcp-regenerate:
	@echo "Regenerating Grafana MCP service account token..."
	@echo "Deleting existing service account via Grafana API..."
	@kubectl port-forward -n monitoring svc/grafana 3000:80 &>/dev/null & \
	PF_PID=$$!; \
	sleep 3; \
	ADMIN_USER=$$(kubectl get secret grafana-admin-secret -n monitoring -o jsonpath='{.data.admin-user}' | base64 -d); \
	ADMIN_PASS=$$(kubectl get secret grafana-admin-secret -n monitoring -o jsonpath='{.data.admin-password}' | base64 -d); \
	SA_ID=$$(curl -sf -u "$$ADMIN_USER:$$ADMIN_PASS" http://localhost:3000/api/serviceaccounts/search?query=mcp-grafana 2>/dev/null | grep -o '"id":[0-9]*' | head -1 | grep -o '[0-9]*'); \
	if [ -n "$$SA_ID" ]; then \
		curl -sf -X DELETE -u "$$ADMIN_USER:$$ADMIN_PASS" "http://localhost:3000/api/serviceaccounts/$$SA_ID" && \
		echo "Deleted service account ID $$SA_ID"; \
	else \
		echo "No existing service account found"; \
	fi; \
	kill $$PF_PID 2>/dev/null; \
	rm -f "$$HOME/.grafana-mcp-token"; \
	echo ""; \
	echo "Triggering ArgoCD sync to recreate service account..."; \
	kubectl delete job grafana-mcp-setup -n monitoring 2>/dev/null || true; \
	kubectl patch application monitoring -n argocd --type merge -p '{"operation":{"initiatedBy":{"username":"admin"},"sync":{"syncStrategy":{"apply":{}}}}}'; \
	echo "Waiting for Job to complete..."; \
	sleep 30; \
	$(MAKE) grafana-mcp-token

# Configure project's .cursor/mcp.json with Grafana MCP token
grafana-mcp-configure:
	@echo "Configuring Cursor MCP for Grafana..."
	@TOKEN_FILE="$$HOME/.grafana-mcp-token"; \
	TOKEN=$$(kubectl logs -n monitoring job/grafana-mcp-setup 2>/dev/null | grep -o 'glsa_[a-zA-Z0-9_]*'); \
	if [ -z "$$TOKEN" ] && [ -f "$$TOKEN_FILE" ]; then \
		TOKEN=$$(cat "$$TOKEN_FILE"); \
	fi; \
	if [ -z "$$TOKEN" ]; then \
		echo "❌ Token not found. Run 'make grafana-mcp-token' first."; \
		exit 1; \
	fi; \
	MCP_FILE=".cursor/mcp.json"; \
	mkdir -p ".cursor"; \
	if [ -f "$$MCP_FILE" ]; then \
		if command -v jq >/dev/null 2>&1; then \
			echo "Updating $$MCP_FILE with new token..."; \
			jq --arg token "$$TOKEN" \
				'.mcpServers.grafana.env.GRAFANA_SERVICE_ACCOUNT_TOKEN = $$token' \
				"$$MCP_FILE" > "$$MCP_FILE.tmp" && mv "$$MCP_FILE.tmp" "$$MCP_FILE"; \
			echo "✅ Updated $$MCP_FILE"; \
		else \
			echo "❌ jq not installed. Install with: brew install jq"; \
			echo ""; \
			echo "Manually update .cursor/mcp.json with:"; \
			echo "  GRAFANA_SERVICE_ACCOUNT_TOKEN: $$TOKEN"; \
			exit 1; \
		fi; \
	else \
		echo "Creating new $$MCP_FILE..."; \
		mkdir -p .cursor; \
		echo '{"mcpServers":{"grafana":{"command":"docker","args":["run","--rm","-i","-e","GRAFANA_URL","-e","GRAFANA_SERVICE_ACCOUNT_TOKEN","mcp/grafana","-t","stdio"],"env":{"GRAFANA_URL":"https://grafana.silverseekers.org","GRAFANA_SERVICE_ACCOUNT_TOKEN":"'"$$TOKEN"'"}}}}' | jq . > "$$MCP_FILE"; \
		echo "✅ Created $$MCP_FILE"; \
	fi; \
	echo "$$TOKEN" > "$$TOKEN_FILE"; \
	echo ""; \
	echo "🔄 Restart Cursor to activate the Grafana MCP server!"

vmsingle-ui:
	@echo "Port-forwarding Victoria Metrics UI..."
	@echo "Victoria Metrics will be available at: http://localhost:8429/vmui"
	kubectl port-forward -n monitoring svc/vmsingle-vmsingle 8429:8429

ping:
	cd ansible && ansible all -m ping

# ============================================================================
# SSH Access (Single Node)
# ============================================================================

ssh-node:
	ssh ubuntu@$$(cd terraform && terraform output -json | jq -r '.vm_ip_addresses.value[0]' | cut -d'/' -f1)

# ============================================================================
# Utility Commands
# ============================================================================

# Render Jinja2 templates to static files for kubectl/Helm deployments
# This allows deployment without Ansible by pre-processing templates
render-templates:
	@echo "📝 Rendering Jinja2 templates for direct kubectl/Helm usage..."
	@mkdir -p rendered/argocd
	@cd ansible && ansible localhost -m template \
		-a "src=../kubernetes/services/argocd/argocd-values.yaml dest=../rendered/argocd/values.yaml" \
		-e "@../config/homelab.yaml" \
		-e "@../config/secrets.yml" \
		-e "argocd_github_repo_url={{ services.argocd.github_repo_url }}" \
		-e "argocd_github_token={{ github_token }}"
	@echo ""
	@echo "✅ Templates rendered to rendered/ directory"
	@echo ""
	@echo "You can now deploy ArgoCD directly with Helm:"
	@echo "  helm upgrade --install argocd argo/argo-cd \\"
	@echo "    --namespace argocd --create-namespace \\"
	@echo "    --values rendered/argocd/values.yaml"
	@echo ""
	@echo "⚠️  Note: rendered/ is gitignored to prevent secrets from being committed"

clean:
	find . -type d -name ".terraform" -exec rm -rf {} + 2>/dev/null || true
	find . -type f -name "*.tfstate.backup" -delete
	find . -type f -name ".DS_Store" -delete
	rm -f ansible/inventory/hosts.yml
	rm -rf ansible/.cache
	@echo "✅ Cleaned temporary files"

clean-backups:
	@echo "🗑️  Removing secret backup files..."
	@echo ""
	@if [ -f letsencrypt-certs-backup.yaml ]; then \
		rm -f letsencrypt-certs-backup.yaml; \
		echo "  ✓ Removed letsencrypt-certs-backup.yaml"; \
	else \
		echo "  - letsencrypt-certs-backup.yaml (not found)"; \
	fi
	@if [ -f sealed-secrets-key-backup.yaml ]; then \
		rm -f sealed-secrets-key-backup.yaml; \
		echo "  ✓ Removed sealed-secrets-key-backup.yaml"; \
	else \
		echo "  - sealed-secrets-key-backup.yaml (not found)"; \
	fi
	@echo ""
	@echo "✅ Backup files removed"
	@echo ""
	@echo "⚠️  Next cluster deployment will:"
	@echo "   - Request new Let's Encrypt certificates (watch rate limits!)"
	@echo "   - Generate new sealed-secrets encryption keys"
	@echo "   - Require re-sealing all secrets with: make seal-secrets"

logs:
	@if [ -f ansible/logs/ansible.log ]; then \
		tail -f ansible/logs/ansible.log; \
	else \
		echo "No Ansible logs found"; \
	fi

# ============================================================================
# Full Stack Deployment (Single Node with Longhorn)
# ============================================================================

# Deploy infrastructure only (Terraform VMs)
deploy-infra:
	@echo "========================================"
	@echo "🚀 Deploying Infrastructure (Terraform)"
	@echo "========================================"
	$(MAKE) apply
	@echo ""
	@echo "✅ Infrastructure deployment complete!"
	@echo ""
	@echo "Next: make deploy-platform"

# Deploy infrastructure + K3s platform
deploy-platform: deploy-infra
	@echo ""
	@echo "========================================"
	@echo "🚀 Deploying K3s Platform"
	@echo "========================================"
	$(MAKE) inventory
	$(MAKE) node-prep
	$(MAKE) k3s-install
	@echo ""
	@echo "✅ Platform deployment complete!"
	@echo ""
	@echo "Set kubeconfig:"
	@echo "  export KUBECONFIG=~/.kube/config-homelab"
	@echo ""
	@echo "Verify cluster:"
	@echo "  kubectl get nodes"
	@echo ""
	@echo "Next: make deploy-services"

# ============================================================================
# Minimal Bootstrap (Ansible) - 4 Services
# These must exist before ArgoCD can deploy everything else
# ============================================================================

deploy-bootstrap: deploy-platform
	@echo ""
	@echo "========================================"
	@echo "🚀 Deploying Minimal Bootstrap (4 services)"
	@echo "========================================"
	@echo ""
	@echo "Bootstrap services: MetalLB, Longhorn, Sealed Secrets, ArgoCD"
	@echo "Everything else will be deployed via ArgoCD."
	@echo ""
	@echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	@echo "Step 1/4: MetalLB (LoadBalancer IPs)"
	@echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	$(MAKE) metallb-install
	@echo ""
	@echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	@echo "Step 2/4: Longhorn (Persistent Storage)"
	@echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	$(MAKE) longhorn-install
	@echo ""
	@echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	@echo "Step 3/4: Sealed Secrets (Secret Encryption)"
	@echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	@# Restore Sealed Secrets keys BEFORE installing controller (preserves existing sealed secrets)
	@if [ -f sealed-secrets-key-backup.yaml ]; then \
		echo "🔐 Restoring Sealed Secrets encryption keys from backup..."; \
		$(MAKE) sealed-secrets-restore; \
		echo ""; \
	fi
	$(MAKE) sealed-secrets-install
	@echo ""
	@# Only re-seal if no backup was restored (new cluster)
	@if [ ! -f sealed-secrets-key-backup.yaml ]; then \
		echo "Sealing secrets with new cluster key..."; \
		$(MAKE) seal-secrets; \
	else \
		echo "ℹ️  Skipping seal-secrets (using restored keys - existing sealed secrets will work)"; \
	fi
	@echo ""
	@echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	@echo "Step 4/4: ArgoCD (GitOps Controller)"
	@echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	$(MAKE) argocd-install
	@echo ""
	@echo "========================================"
	@echo "✅ Bootstrap deployment complete!"
	@echo "========================================"
	@echo ""
	@ARGOCD_IP=$$(kubectl get svc argocd-server -n argocd -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "pending"); \
	echo "ArgoCD is accessible via LoadBalancer IP: https://$$ARGOCD_IP"; \
	echo ""
	@echo "Next steps:"
	@echo "  1. Access ArgoCD via IP (no ingress yet)"
	@echo "  2. Deploy all services: make deploy-services"
	@echo ""
	@echo "ArgoCD will deploy (in order):"
	@echo "  Wave 1: Cert-Manager (TLS)"
	@echo "  Wave 2: Traefik (Ingress)"
	@echo "  Wave 3: Authelia, NetworkPolicies, LimitRanges"
	@echo "  Wave 4: Loki, Promtail, MinIO, Velero, Cloudflared, External-DNS"
	@echo "  Wave 5: Monitoring, future apps"

# ============================================================================
# Deploy Services via ArgoCD
# Everything after bootstrap is managed by ArgoCD
# ============================================================================

deploy-services:
	@echo ""
	@echo "========================================"
	@echo "🚀 Deploying All Services via ArgoCD"
	@echo "========================================"
	@echo ""
	@echo "Applying root-app - ArgoCD will deploy all services..."
	kubectl apply -f kubernetes/applications/root-app.yaml
	@echo ""
	@echo "ArgoCD will automatically deploy in sync-wave order:"
	@echo "  Wave 1: Cert-Manager"
	@echo "  Wave 2: Traefik"
	@echo "  Wave 3: Authelia, NetworkPolicies, LimitRanges"
	@echo "  Wave 4: Loki, Promtail, MinIO, Velero, Cloudflared, External-DNS"
	@echo "  Wave 5: Monitoring"
	@echo ""
	@echo "Monitor deployment progress:"
	@echo "  kubectl get applications -n argocd"
	@echo "  make apps-status"
	@echo ""
	@# Restore TLS certificates if backup exists (avoids Let's Encrypt rate limits)
	@if [ -f letsencrypt-certs-backup.yaml ]; then \
		echo "📦 Restoring TLS certificates from backup..."; \
		$(MAKE) certs-restore; \
		echo ""; \
	fi
	@echo ""
	@echo "========================================"
	@echo "✅ Services deployment initiated!"
	@echo "========================================"
	@echo ""
	@echo "Access Points (once deployed):"
	@echo "  Traefik:   https://traefik.silverseekers.org"
	@echo "  ArgoCD:    https://argocd.silverseekers.org"
	@echo "  Authelia:  https://auth.silverseekers.org"
	@echo "  Longhorn:  https://longhorn.silverseekers.org"
	@echo "  Grafana:   https://grafana.silverseekers.org"
	@echo ""
	@echo "Storage Classes:"
	@echo "  local-path (default) - ephemeral data"
	@echo "  longhorn             - persistent data (apps, databases)"
	@echo ""
	@echo "DNS Configuration:"
	@echo "  Configure UniFi Gateway with wildcard DNS:"
	@echo "    *.silverseekers.org -> 192.168.10.150"

# Deploy everything: infra + platform + bootstrap + services
deploy-all: deploy-bootstrap
	@echo ""
	$(MAKE) deploy-services
	@echo ""
	@echo "========================================"
	@echo "✅ FULL STACK DEPLOYMENT COMPLETE!"
	@echo "========================================"
	@echo ""
	@echo "🎉 Your homelab is ready!"
	@echo ""
	@echo "Single-Node Configuration:"
	@echo "  RAM:     12 GB"
	@echo "  Storage: Longhorn (1 replica) + local-path"
	@echo ""
	@echo "Access Points:"
	@echo "  Grafana:  https://grafana.silverseekers.org"
	@echo "  ArgoCD:   https://argocd.silverseekers.org"
	@echo "  Traefik:  https://traefik.silverseekers.org"
	@echo "  Longhorn: https://longhorn.silverseekers.org"
	@echo ""
	@echo "DNS Configuration:"
	@echo "  Configure UniFi Gateway with wildcard DNS:"
	@echo "    *.silverseekers.org -> 192.168.10.150"
	@echo ""
	@echo "Check status:"
	@echo "  kubectl get nodes"
	@echo "  kubectl get pods -A"
	@echo "  make argocd-ui"
	@echo "  make grafana-ui"
	@echo ""
	@echo "💡 Monitor ArgoCD sync:"
	@echo "  make apps-status"

# Alias: deploy = deploy-all (most common use case)
deploy: deploy-all

# Deploy only applications (assumes services are already deployed)
deploy-apps:
	@echo "========================================"
	@echo "🚀 Deploying Applications"
	@echo "========================================"
	@echo "Creating monitoring secrets..."
	$(MAKE) monitoring-secrets
	@echo ""
	@echo "Deploying monitoring stack via ArgoCD..."
	$(MAKE) monitoring-deploy
	@echo ""
	@echo "✅ Applications deployment complete!"
	@echo ""
	@echo "Access Points:"
	@echo "  Grafana: https://grafana.silverseekers.org"
	@echo ""
	@echo "💡 Monitor ArgoCD sync:"
	@echo "  make apps-status"
	@echo "  make monitoring-sync"

# ============================================================================
# Full Cluster Rebuild (Nuclear Option)
# ============================================================================

# Complete cluster rebuild - destroys everything and starts fresh
# This is the "nuclear option" for when you need a completely clean slate
rebuild:
	@echo "════════════════════════════════════════════════════════════════════"
	@echo "🔥 FULL CLUSTER REBUILD - NUCLEAR OPTION"
	@echo "════════════════════════════════════════════════════════════════════"
	@echo ""
	@echo "This will:"
	@echo "  1. Destroy all infrastructure (VMs, storage, network)"
	@echo "  2. Clean all temporary files"
	@echo "  3. Remove all secret backups (fresh certs & sealed-secrets keys)"
	@echo "  4. Re-initialize Terraform"
	@echo "  5. Redeploy entire stack from scratch"
	@echo ""
	@echo "⚠️  WARNING: All data will be lost. Backups will be deleted."
	@echo ""
	@read -p "Are you ABSOLUTELY sure? Type 'REBUILD' to confirm: " confirm; \
	if [ "$$confirm" != "REBUILD" ]; then \
		echo "❌ Rebuild cancelled."; \
		exit 1; \
	fi
	@echo ""
	@echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	@echo "Step 1/5: Destroying infrastructure..."
	@echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	$(MAKE) destroy
	@echo ""
	@echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	@echo "Step 2/5: Cleaning temporary files..."
	@echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	$(MAKE) clean
	@echo ""
	@echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	@echo "Step 3/5: Removing secret backups..."
	@echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	$(MAKE) clean-backups
	@echo ""
	@echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	@echo "Step 4/5: Re-initializing Terraform..."
	@echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	$(MAKE) init
	@echo ""
	@echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	@echo "Step 5/5: Deploying full stack..."
	@echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	$(MAKE) deploy-all
	@echo ""
	@echo "════════════════════════════════════════════════════════════════════"
	@echo "🎉 REBUILD COMPLETE!"
	@echo "════════════════════════════════════════════════════════════════════"
