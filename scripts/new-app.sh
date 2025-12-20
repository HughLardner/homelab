#!/bin/bash
#
# new-app.sh - Generate a new application scaffold for the homelab cluster
#
# Usage:
#   ./scripts/new-app.sh myapp
#   ./scripts/new-app.sh myapp --port 3000 --auth --storage 10Gi
#
# Options:
#   --port PORT       Service port (default: 8080)
#   --auth            Enable Authelia SSO protection
#   --no-auth         Disable Authelia SSO protection (default)
#   --storage SIZE    Enable persistent storage with size (e.g., 5Gi, 10Gi)
#   --image IMAGE     Container image (default: nginx:alpine)
#   --wave NUMBER     ArgoCD sync wave (default: 5)
#   --type TYPE       App type: 'application' or 'service' (default: application)
#   --help            Show this help message
#

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
APP_NAME=""
APP_PORT="8080"
AUTH_ENABLED="false"
STORAGE_ENABLED="false"
STORAGE_SIZE="5Gi"
CONTAINER_IMAGE="nginx:alpine"
SYNC_WAVE="5"
APP_TYPE="application"

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Help message
show_help() {
    cat << EOF
Usage: $(basename "$0") APP_NAME [OPTIONS]

Generate a new application scaffold for the homelab cluster.

Arguments:
  APP_NAME              Name of the application (lowercase, alphanumeric with hyphens)

Options:
  --port PORT           Service port (default: 8080)
  --auth                Enable Authelia SSO protection
  --no-auth             Disable Authelia SSO protection (default)
  --storage SIZE        Enable persistent storage with size (e.g., 5Gi, 10Gi)
  --image IMAGE         Container image (default: nginx:alpine)
  --wave NUMBER         ArgoCD sync wave (default: 5)
  --type TYPE           App type: 'application' or 'service' (default: application)
  --help                Show this help message

Examples:
  $(basename "$0") myapp
  $(basename "$0") myapp --port 3000 --auth
  $(basename "$0") myapp --port 8080 --storage 10Gi --image myregistry/myapp:latest
  $(basename "$0") myservice --type service --wave 3

EOF
}

# Parse arguments
parse_args() {
    if [[ $# -eq 0 ]]; then
        show_help
        exit 1
    fi

    while [[ $# -gt 0 ]]; do
        case $1 in
            --help|-h)
                show_help
                exit 0
                ;;
            --port)
                APP_PORT="$2"
                shift 2
                ;;
            --auth)
                AUTH_ENABLED="true"
                shift
                ;;
            --no-auth)
                AUTH_ENABLED="false"
                shift
                ;;
            --storage)
                STORAGE_ENABLED="true"
                STORAGE_SIZE="$2"
                shift 2
                ;;
            --image)
                CONTAINER_IMAGE="$2"
                shift 2
                ;;
            --wave)
                SYNC_WAVE="$2"
                shift 2
                ;;
            --type)
                APP_TYPE="$2"
                shift 2
                ;;
            -*)
                echo -e "${RED}Error: Unknown option $1${NC}"
                show_help
                exit 1
                ;;
            *)
                if [[ -z "$APP_NAME" ]]; then
                    APP_NAME="$1"
                else
                    echo -e "${RED}Error: Unexpected argument $1${NC}"
                    show_help
                    exit 1
                fi
                shift
                ;;
        esac
    done

    # Validate app name
    if [[ -z "$APP_NAME" ]]; then
        echo -e "${RED}Error: APP_NAME is required${NC}"
        show_help
        exit 1
    fi

    if [[ ! "$APP_NAME" =~ ^[a-z][a-z0-9-]*$ ]]; then
        echo -e "${RED}Error: APP_NAME must be lowercase, start with a letter, and contain only letters, numbers, and hyphens${NC}"
        exit 1
    fi

    # Set target directory based on type
    if [[ "$APP_TYPE" == "service" ]]; then
        TARGET_DIR="$PROJECT_ROOT/kubernetes/services/$APP_NAME"
    else
        TARGET_DIR="$PROJECT_ROOT/kubernetes/applications/$APP_NAME"
    fi
}

# Create directory structure
create_directories() {
    echo -e "${BLUE}Creating directory structure...${NC}"
    mkdir -p "$TARGET_DIR/templates"
    mkdir -p "$TARGET_DIR/secrets"
}

# Generate Chart.yaml
generate_chart() {
    echo -e "${BLUE}Generating Chart.yaml...${NC}"
    cat > "$TARGET_DIR/Chart.yaml" << EOF
apiVersion: v2
name: $APP_NAME
description: $APP_NAME application
type: application
version: 1.0.0
appVersion: "1.0.0"
EOF
}

# Generate values.yaml
generate_values() {
    echo -e "${BLUE}Generating values.yaml...${NC}"
    cat > "$TARGET_DIR/values.yaml" << EOF
# Default values for $APP_NAME
# This chart inherits global values from config/homelab.yaml

replicaCount: 1

image:
  repository: ${CONTAINER_IMAGE%%:*}
  tag: ${CONTAINER_IMAGE#*:}
  pullPolicy: IfNotPresent

service:
  port: $APP_PORT
  type: ClusterIP

# Authelia SSO protection
auth_enabled: $AUTH_ENABLED

# Persistent storage
persistence:
  enabled: $STORAGE_ENABLED
  size: $STORAGE_SIZE
  storageClass: longhorn

# Resource limits
resources:
  requests:
    cpu: 100m
    memory: 128Mi
  limits:
    cpu: 500m
    memory: 512Mi
EOF
}

# Generate application.yaml (ArgoCD)
generate_application() {
    echo -e "${BLUE}Generating application.yaml...${NC}"
    
    local path_prefix
    if [[ "$APP_TYPE" == "service" ]]; then
        path_prefix="kubernetes/services"
    else
        path_prefix="kubernetes/applications"
    fi
    
    cat > "$TARGET_DIR/application.yaml" << EOF
---
# ArgoCD Application for $APP_NAME
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: $APP_NAME
  namespace: argocd
  finalizers:
    - resources-finalizer.argocd.argoproj.io
  annotations:
    argocd.argoproj.io/sync-wave: "$SYNC_WAVE"
spec:
  project: default

  sources:
    # 1. Application chart
    - repoURL: https://github.com/HughLardner/homelab.git
      targetRevision: HEAD
      path: $path_prefix/$APP_NAME
      helm:
        releaseName: $APP_NAME
        valueFiles:
          - \$values/config/homelab.yaml
          - values.yaml

    # 2. Values reference
    - repoURL: https://github.com/HughLardner/homelab.git
      targetRevision: HEAD
      ref: values

    # 3. Sealed secrets
    - repoURL: https://github.com/HughLardner/homelab.git
      targetRevision: HEAD
      path: $path_prefix/$APP_NAME/secrets
      directory:
        recurse: false
        include: "*.yaml"

  destination:
    server: https://kubernetes.default.svc
    namespace: $APP_NAME

  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
      - ServerSideApply=true
    retry:
      limit: 5
      backoff:
        duration: 5s
        factor: 2
        maxDuration: 3m
EOF
}

# Generate deployment.yaml
generate_deployment() {
    echo -e "${BLUE}Generating templates/deployment.yaml...${NC}"
    cat > "$TARGET_DIR/templates/deployment.yaml" << 'EOF'
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ .Release.Name }}
  namespace: {{ .Release.Namespace }}
  labels:
    app.kubernetes.io/name: {{ .Release.Name }}
spec:
  replicas: {{ .Values.replicaCount | default 1 }}
  selector:
    matchLabels:
      app.kubernetes.io/name: {{ .Release.Name }}
  template:
    metadata:
      labels:
        app.kubernetes.io/name: {{ .Release.Name }}
    spec:
      containers:
        - name: {{ .Release.Name }}
          image: "{{ .Values.image.repository }}:{{ .Values.image.tag }}"
          imagePullPolicy: {{ .Values.image.pullPolicy }}
          ports:
            - name: http
              containerPort: {{ .Values.service.port }}
              protocol: TCP
          envFrom:
            - secretRef:
                name: {{ .Release.Name }}-secrets
                optional: true
          resources:
            {{- toYaml .Values.resources | nindent 12 }}
          livenessProbe:
            httpGet:
              path: /
              port: http
            initialDelaySeconds: 30
            periodSeconds: 10
          readinessProbe:
            httpGet:
              path: /
              port: http
            initialDelaySeconds: 5
            periodSeconds: 5
          {{- if .Values.persistence.enabled }}
          volumeMounts:
            - name: data
              mountPath: /data
          {{- end }}
      {{- if .Values.persistence.enabled }}
      volumes:
        - name: data
          persistentVolumeClaim:
            claimName: {{ .Release.Name }}-data
      {{- end }}
EOF
}

# Generate service.yaml
generate_service() {
    echo -e "${BLUE}Generating templates/service.yaml...${NC}"
    cat > "$TARGET_DIR/templates/service.yaml" << 'EOF'
---
apiVersion: v1
kind: Service
metadata:
  name: {{ .Release.Name }}
  namespace: {{ .Release.Namespace }}
  labels:
    app.kubernetes.io/name: {{ .Release.Name }}
spec:
  type: {{ .Values.service.type | default "ClusterIP" }}
  ports:
    - port: {{ .Values.service.port }}
      targetPort: http
      protocol: TCP
      name: http
  selector:
    app.kubernetes.io/name: {{ .Release.Name }}
EOF
}

# Generate ingressroute.yaml
generate_ingressroute() {
    echo -e "${BLUE}Generating templates/ingressroute.yaml...${NC}"
    cat > "$TARGET_DIR/templates/ingressroute.yaml" << 'EOF'
---
apiVersion: traefik.io/v1alpha1
kind: IngressRoute
metadata:
  name: {{ .Release.Name }}
  namespace: {{ .Release.Namespace }}
  annotations:
    kubernetes.io/ingress.class: traefik
  labels:
    app.kubernetes.io/name: {{ .Release.Name }}
spec:
  entryPoints:
    - websecure
  routes:
    - match: Host(`{{ .Release.Name }}.{{ .Values.global.domain }}`)
      kind: Rule
      priority: 10
      {{- if .Values.auth_enabled }}
      middlewares:
        - name: authelia-forward-auth
          namespace: authelia
      {{- end }}
      services:
        - name: {{ .Release.Name }}
          port: {{ .Values.service.port }}
  tls:
    secretName: {{ .Release.Name }}-tls
EOF
}

# Generate certificate.yaml
generate_certificate() {
    echo -e "${BLUE}Generating templates/certificate.yaml...${NC}"
    cat > "$TARGET_DIR/templates/certificate.yaml" << 'EOF'
---
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: {{ .Release.Name }}-tls
  namespace: {{ .Release.Namespace }}
  labels:
    app.kubernetes.io/name: {{ .Release.Name }}
spec:
  secretName: {{ .Release.Name }}-tls
  issuerRef:
    name: {{ .Values.global.cert_issuer | default "letsencrypt-prod" }}
    kind: ClusterIssuer
  dnsNames:
    - {{ .Release.Name }}.{{ .Values.global.domain }}
  privateKey:
    algorithm: ECDSA
    size: 256
EOF
}

# Generate pvc.yaml (optional)
generate_pvc() {
    echo -e "${BLUE}Generating templates/pvc.yaml...${NC}"
    cat > "$TARGET_DIR/templates/pvc.yaml" << 'EOF'
{{- if .Values.persistence.enabled }}
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: {{ .Release.Name }}-data
  namespace: {{ .Release.Namespace }}
  labels:
    app.kubernetes.io/name: {{ .Release.Name }}
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: {{ .Values.persistence.storageClass | default "longhorn" }}
  resources:
    requests:
      storage: {{ .Values.persistence.size | default "5Gi" }}
{{- end }}
EOF
}

# Generate README.md
generate_readme() {
    echo -e "${BLUE}Generating README.md...${NC}"
    cat > "$TARGET_DIR/README.md" << EOF
# $APP_NAME

## Overview

$APP_NAME application deployed via ArgoCD GitOps.

## Configuration

| Setting | Value |
|---------|-------|
| Port | $APP_PORT |
| Auth Enabled | $AUTH_ENABLED |
| Storage | $STORAGE_ENABLED ($STORAGE_SIZE) |
| Image | $CONTAINER_IMAGE |
| Sync Wave | $SYNC_WAVE |

## Access

- **URL**: https://$APP_NAME.silverseekers.org
- **Namespace**: $APP_NAME

## Secrets

Add secrets to \`config/secrets.yml\`:

\`\`\`yaml
secrets:
  - name: $APP_NAME-secrets
    namespace: $APP_NAME
    type: Opaque
    data:
      MY_SECRET: "secret-value"
    output_path: $TARGET_DIR/secrets/$APP_NAME-secrets-sealed.yaml
\`\`\`

Then run:

\`\`\`bash
make seal-secrets
\`\`\`

## Files

\`\`\`
$APP_NAME/
├── application.yaml      # ArgoCD Application
├── Chart.yaml            # Helm chart metadata
├── values.yaml           # Default values
├── README.md             # This file
├── templates/
│   ├── deployment.yaml   # Deployment
│   ├── service.yaml      # Service
│   ├── ingressroute.yaml # Traefik ingress
│   ├── certificate.yaml  # TLS certificate
│   └── pvc.yaml          # Persistent storage
└── secrets/
    └── (sealed secrets)
\`\`\`

## Deployment

Push to git and ArgoCD will automatically deploy:

\`\`\`bash
git add .
git commit -m "Add $APP_NAME"
git push
\`\`\`
EOF
}

# Generate .gitkeep for secrets directory
generate_gitkeep() {
    touch "$TARGET_DIR/secrets/.gitkeep"
}

# Main function
main() {
    parse_args "$@"
    
    echo -e "${GREEN}╔════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║  Generating application: $APP_NAME${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "  Port:     ${YELLOW}$APP_PORT${NC}"
    echo -e "  Auth:     ${YELLOW}$AUTH_ENABLED${NC}"
    echo -e "  Storage:  ${YELLOW}$STORAGE_ENABLED ($STORAGE_SIZE)${NC}"
    echo -e "  Image:    ${YELLOW}$CONTAINER_IMAGE${NC}"
    echo -e "  Wave:     ${YELLOW}$SYNC_WAVE${NC}"
    echo -e "  Type:     ${YELLOW}$APP_TYPE${NC}"
    echo -e "  Path:     ${YELLOW}$TARGET_DIR${NC}"
    echo ""
    
    # Check if directory already exists
    if [[ -d "$TARGET_DIR" ]]; then
        echo -e "${RED}Error: Directory already exists: $TARGET_DIR${NC}"
        echo -e "Remove it first or choose a different name."
        exit 1
    fi
    
    create_directories
    generate_chart
    generate_values
    generate_application
    generate_deployment
    generate_service
    generate_ingressroute
    generate_certificate
    generate_pvc
    generate_readme
    generate_gitkeep
    
    echo ""
    echo -e "${GREEN}✅ Application scaffold created successfully!${NC}"
    echo ""
    echo -e "${BLUE}Next steps:${NC}"
    echo "  1. Review and customize the generated files"
    echo "  2. Add secrets to config/secrets.yml (if needed)"
    echo "  3. Run: make seal-secrets"
    echo "  4. Commit and push:"
    echo "     git add $TARGET_DIR"
    echo "     git commit -m \"Add $APP_NAME application\""
    echo "     git push"
    echo ""
    echo -e "${BLUE}ArgoCD will automatically deploy your application!${NC}"
}

main "$@"

