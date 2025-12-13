.PHONY: help init plan apply destroy ssh-node k3s-* metallb-* longhorn-* cert-manager-* traefik-* argocd-* authelia-* monitoring-* sealed-secrets-* seal-secrets kured-* root-app-deploy apps-list apps-status monitoring-secrets inventory clean deploy-infra deploy-platform deploy-services deploy-all deploy deploy-apps

# Default target
help:
	@echo "Homelab Infrastructure Makefile"
	@echo ""
	@echo "Single-Node K3s Cluster (12GB RAM, Longhorn + local-path storage)"
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
	@echo "  make longhorn-install  - Install Longhorn (Distributed Storage)"
	@echo "  make longhorn-ingress  - Configure Longhorn IngressRoute (after Traefik)"
	@echo "  make longhorn-status   - Check Longhorn status"
	@echo "  make longhorn-ui       - Open Longhorn UI"
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
	@echo "  make authelia-secrets       - Apply Authelia sealed secrets (prerequisite)"
	@echo "  make authelia-install       - Install Authelia SSO Platform"
	@echo "  make authelia-status        - Check Authelia status"
	@echo "  make authelia-ui            - Open Authelia SSO UI"
	@echo "  make authelia-logs          - View Authelia logs"
	@echo "  make kured-deploy           - Deploy Kured via ArgoCD (Automated Node Reboots)"
	@echo "  make kured-status           - Check Kured status"
	@echo "  make kured-logs             - View Kured logs"
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
	@echo "  make grafana-mcp-token     - Get Grafana MCP service account token"
	@echo "  make grafana-mcp-configure - Auto-configure .cursor/mcp.json with Grafana token"
	@echo "  make grafana-mcp-regenerate - Regenerate the Grafana MCP token"
	@echo "  make vmsingle-ui           - Port-forward Victoria Metrics UI"
	@echo "  make ping                 - Test connectivity to all nodes"
	@echo ""
	@echo "Full Stack Deployment:"
	@echo "  make deploy-infra      - Deploy infrastructure only (Terraform VMs)"
	@echo "  make deploy-platform   - Deploy infrastructure + K3s cluster"
	@echo "  make deploy-services   - Deploy infrastructure + K3s + all core services"
	@echo "  make deploy-all        - Deploy everything (infra + platform + services + apps)"
	@echo "  make deploy            - Alias for deploy-services (most common)"
	@echo "  make deploy-apps       - Deploy only applications (assumes services exist)"
	@echo ""
	@echo "SSH Commands:"
	@echo "  make ssh-node      - SSH to the K3s node"
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

monitoring-install: inventory
	@echo "Installing Monitoring Stack (Victoria Metrics + Grafana)..."
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

# Deploy infrastructure + K3s + all core services
deploy-services: deploy-platform
	@echo ""
	@echo "========================================"
	@echo "🚀 Deploying Core Services"
	@echo "========================================"
	@echo "Installing MetalLB (LoadBalancer)..."
	$(MAKE) metallb-install
	@echo ""
	@echo "Installing Longhorn (Distributed Storage)..."
	$(MAKE) longhorn-install
	@echo ""
	@echo "Installing Cert-Manager (TLS)..."
	$(MAKE) cert-manager-install
	@echo ""
	@echo "Installing Traefik (Ingress)..."
	$(MAKE) traefik-install
	@echo ""
	@echo "Configuring Longhorn IngressRoute..."
	$(MAKE) longhorn-ingress
	@echo ""
	@echo "Installing ArgoCD (GitOps)..."
	$(MAKE) argocd-install
	@echo ""
	@echo "Installing Sealed Secrets (Secret Encryption)..."
	$(MAKE) sealed-secrets-install
	@echo ""
	@echo "Sealing secrets with cluster key..."
	$(MAKE) seal-secrets
	@echo ""
	@echo "Applying Authelia Secrets..."
	$(MAKE) authelia-secrets
	@echo ""
	@echo "Installing Authelia SSO Platform..."
	$(MAKE) authelia-install
	@echo ""
	@echo "✅ Core services deployment complete!"
	@echo ""
	@echo "Access Points:"
	@echo "  Traefik:   https://traefik.silverseekers.org"
	@echo "  ArgoCD:    https://argocd.silverseekers.org"
	@echo "  Authelia:  https://auth.silverseekers.org"
	@echo "  Longhorn:  https://longhorn.silverseekers.org"
	@echo ""
	@echo "Storage Classes:"
	@echo "  local-path (default) - ephemeral data"
	@echo "  longhorn             - persistent data (apps, databases)"
	@echo ""
	@echo "DNS Configuration:"
	@echo "  Configure UniFi Gateway with wildcard DNS:"
	@echo "    *.silverseekers.org -> 192.168.10.150"
	@echo ""
	@echo "Next: make deploy-apps"

# Deploy everything including applications
deploy-all: deploy-services
	@echo ""
	@echo "========================================"
	@echo "🚀 Deploying Applications"
	@echo "========================================"
	@echo "Creating monitoring secrets..."
	$(MAKE) monitoring-secrets
	@echo ""
	@echo "Deploying monitoring stack via ArgoCD..."
	$(MAKE) monitoring-deploy
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
	@echo "  Longhorn: http://192.168.10.144"
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
	@echo "  make monitoring-sync"

# Alias: deploy = deploy-services (most common use case)
deploy: deploy-services
	@echo ""
	@echo "💡 TIP: To deploy applications too, run: make deploy-all"

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
