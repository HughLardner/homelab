# Filestash Secrets

Filestash manages its own configuration state internally.
No pre-configured secrets are required for deployment.

## S3 Credentials

S3 access keys are configured by users through the Filestash web UI,
not through Kubernetes secrets. This allows different users to use
different credentials with different permission levels.

## Getting Garage Access Keys

```bash
# List all keys
kubectl exec -n garage garage-0 -- garage key list

# Get key details
kubectl exec -n garage garage-0 -- garage key info <key_id>

# Create a new key
kubectl exec -n garage garage-0 -- garage key create filestash-user

# Grant bucket access
kubectl exec -n garage garage-0 -- garage bucket allow velero --read --write --key filestash-user
```
