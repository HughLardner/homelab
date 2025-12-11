# Grafana MCP Integration

This guide explains how to set up [mcp-grafana](https://github.com/grafana/mcp-grafana) to enable AI assistants (like Claude in Cursor) to interact with your Grafana instance.

## Overview

The Grafana MCP (Model Context Protocol) server allows AI assistants to:

- Query Prometheus/Loki datasources
- Search and manage dashboards
- View and manage alerts
- Execute PromQL/LogQL queries
- Investigate incidents (Grafana Cloud)

## Prerequisites

- Grafana deployed and accessible (via `make monitoring-deploy`)
- kubectl configured with cluster access
- Docker installed (recommended) or Homebrew/Go for native binary

## Setup Steps

### 1. Create Grafana Service Account

Run the automated setup command:

```bash
make grafana-mcp-setup
```

This will:
- Create a `mcp-grafana` service account with Admin role
- Generate an API token valid for 1 year
- Output the configuration for your MCP client

### 2. Configure Cursor MCP

Add the following to your `~/.cursor/mcp.json`:

#### Option 1: Docker (Recommended - No Installation Required)

Docker automatically pulls the image on first run. No manual installation needed.

```json
{
  "mcpServers": {
    "grafana": {
      "command": "docker",
      "args": [
        "run", "--rm", "-i",
        "-e", "GRAFANA_URL",
        "-e", "GRAFANA_SERVICE_ACCOUNT_TOKEN",
        "mcp/grafana",
        "-t", "stdio"
      ],
      "env": {
        "GRAFANA_URL": "https://grafana.silverseekers.org",
        "GRAFANA_SERVICE_ACCOUNT_TOKEN": "<your-token-from-step-1>"
      }
    }
  }
}
```

**Important:** The `-t stdio` flag is required! The Docker image defaults to SSE mode, but Cursor needs stdio mode for direct communication.

**Note:** The first time Cursor starts the MCP server, Docker will pull the `mcp/grafana` image (~50MB). Subsequent starts are instant.

#### Option 2: Native Binary (Homebrew/Go)

If you prefer a native binary:

```bash
# macOS
brew install grafana/tap/mcp-grafana

# Or via Go
go install github.com/grafana/mcp-grafana/cmd/mcp-grafana@latest
```

Then configure:

```json
{
  "mcpServers": {
    "grafana": {
      "command": "mcp-grafana",
      "args": [],
      "env": {
        "GRAFANA_URL": "https://grafana.silverseekers.org",
        "GRAFANA_SERVICE_ACCOUNT_TOKEN": "<your-token-from-step-1>"
      }
    }
  }
}
```

### 3. Restart Cursor

After updating `mcp.json`, restart Cursor to load the new MCP server.

## Available Tools

Once configured, the following tools become available:

| Tool | Description |
|------|-------------|
| `search_dashboards` | Search for dashboards by title |
| `get_dashboard_by_uid` | Get dashboard details by UID |
| `list_datasources` | List all configured datasources |
| `query_prometheus` | Execute PromQL queries |
| `query_loki` | Execute LogQL queries |
| `list_alert_rules` | List all alert rules |
| `get_alert_rule_by_uid` | Get specific alert rule details |
| `list_incidents` | List incidents (Grafana Cloud) |
| `investigate` | Start an investigation (Grafana Cloud) |

## Usage Examples

### Query Cluster Metrics

Ask the AI assistant:
> "What's the current CPU usage across all nodes?"

The assistant will use `query_prometheus` to execute:
```promql
100 - (avg by(instance) (rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)
```

### Find Dashboards

> "Show me all Kubernetes-related dashboards"

### Check Alerts

> "Are there any firing alerts in the cluster?"

### Memory Usage Analysis

> "What pods are using the most memory in the monitoring namespace?"

## Token Management

### Generate New Token

If your token expires or you need a new one:

```bash
make grafana-mcp-token
```

### Manage Tokens in UI

Visit: https://grafana.silverseekers.org/admin/serviceaccounts

## Troubleshooting

### Connection Issues

1. Verify Grafana is accessible:
   ```bash
   curl -I https://grafana.silverseekers.org
   ```

2. Test token validity:
   ```bash
   curl -H "Authorization: Bearer <your-token>" \
        https://grafana.silverseekers.org/api/org
   ```

### MCP Server Not Loading

1. Check Cursor logs for MCP errors

2. **For Docker users**, verify Docker is running:
   ```bash
   docker info
   ```

3. Test the MCP server directly:
   ```bash
   # Docker (must use -t stdio for Cursor compatibility)
   docker run --rm -it \
     -e GRAFANA_URL=https://grafana.silverseekers.org \
     -e GRAFANA_SERVICE_ACCOUNT_TOKEN=<token> \
     mcp/grafana -t stdio -debug

   # Native binary
   GRAFANA_URL=https://grafana.silverseekers.org \
   GRAFANA_SERVICE_ACCOUNT_TOKEN=<token> \
   mcp-grafana -debug
   ```

4. **For native binary users**, verify it's in your PATH:
   ```bash
   which mcp-grafana
   ```

### SSL/TLS Issues

If using self-signed certificates, add `--tls-skip-verify` flag:

**Docker:**
```json
{
  "mcpServers": {
    "grafana": {
      "command": "docker",
      "args": [
        "run", "--rm", "-i",
        "-e", "GRAFANA_URL",
        "-e", "GRAFANA_SERVICE_ACCOUNT_TOKEN",
        "mcp/grafana",
        "-t", "stdio",
        "--tls-skip-verify"
      ],
      "env": {
        "GRAFANA_URL": "https://grafana.silverseekers.org",
        "GRAFANA_SERVICE_ACCOUNT_TOKEN": "<token>"
      }
    }
  }
}
```

**Native binary:**
```json
{
  "mcpServers": {
    "grafana": {
      "command": "mcp-grafana",
      "args": ["--tls-skip-verify"],
      "env": {
        "GRAFANA_URL": "https://grafana.silverseekers.org",
        "GRAFANA_SERVICE_ACCOUNT_TOKEN": "<token>"
      }
    }
  }
}
```

## Security Considerations

- Service account tokens should be treated as secrets
- The `mcp-grafana` service account has Admin access - consider using Editor or Viewer role for restricted access
- Tokens expire after 1 year by default - set a reminder to rotate them
- Never commit tokens to version control

## References

- [mcp-grafana GitHub Repository](https://github.com/grafana/mcp-grafana)
- [Grafana Service Accounts Documentation](https://grafana.com/docs/grafana/latest/administration/service-accounts/)
- [Model Context Protocol](https://modelcontextprotocol.io/)

