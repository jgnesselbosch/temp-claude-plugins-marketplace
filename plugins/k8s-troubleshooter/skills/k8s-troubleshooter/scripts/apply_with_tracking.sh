#!/bin/bash
# apply_with_tracking.sh - Apply Kubernetes manifests with automatic tracking

set -euo pipefail

MANIFEST_FILE="$1"
CHANGE_FILE="${CHANGE_FILE:-/tmp/k8s-changes-$(date +%Y%m%d-%H%M%S).yaml}"

if [ ! -f "$MANIFEST_FILE" ]; then
    echo "Error: Manifest file not found: $MANIFEST_FILE"
    exit 1
fi

# Extract resource information
RESOURCE_TYPE=$(kubectl apply -f "$MANIFEST_FILE" --dry-run=client -o name | cut -d'/' -f1)
RESOURCE_NAME=$(kubectl apply -f "$MANIFEST_FILE" --dry-run=client -o name | cut -d'/' -f2)
NAMESPACE=$(grep -E '^\s*namespace:' "$MANIFEST_FILE" | head -1 | awk '{print $2}')
NAMESPACE="${NAMESPACE:-default}"

# Check if resource exists (for update vs create detection)
if kubectl get "$RESOURCE_TYPE" "$RESOURCE_NAME" -n "$NAMESPACE" &>/dev/null; then
    OPERATION="UPDATE"
    # Backup existing resource
    echo "Backing up existing resource..."
    kubectl get "$RESOURCE_TYPE" "$RESOURCE_NAME" -n "$NAMESPACE" -o yaml > \
        "/tmp/backup-${RESOURCE_TYPE}-${RESOURCE_NAME}-$(date +%Y%m%d-%H%M%S).yaml"
else
    OPERATION="CREATE"
fi

# Apply the manifest
echo "Applying manifest..."
if kubectl apply -f "$MANIFEST_FILE"; then
    echo "✓ Successfully applied $RESOURCE_TYPE/$RESOURCE_NAME"
    
    # Track the change
    echo "Tracking change..."
    source "$(dirname "$0")/track_change.sh"
    track_change "$RESOURCE_TYPE" "$RESOURCE_NAME" "$NAMESPACE" "$OPERATION" "$(cat "$MANIFEST_FILE")"
    
    # Verify the resource
    echo "Verifying resource state..."
    kubectl get "$RESOURCE_TYPE" "$RESOURCE_NAME" -n "$NAMESPACE"
else
    echo "✗ Failed to apply manifest"
    exit 1
fi

echo ""
echo "Change tracked in: $CHANGE_FILE"
echo "Use 'show-k8s-changes' to view all session changes"
