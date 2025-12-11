#!/bin/bash
# update_jira.sh - Simple wrapper for Jira integration

set -euo pipefail

TICKET_ID="${1:-}"

if [ -z "$TICKET_ID" ]; then
    echo "Usage: $0 <TICKET-ID> [options]"
    echo "Example: $0 PROJ-123"
    echo ""
    echo "Environment variables required:"
    echo "  JIRA_USER - Your Jira email"
    echo "  JIRA_TOKEN - Your Jira API token"
    echo "  JIRA_URL - Jira base URL (optional, defaults to https://jira.company.com)"
    exit 1
fi

# Check for required environment variables
if [ -z "${JIRA_USER:-}" ] || [ -z "${JIRA_TOKEN:-}" ]; then
    echo "Error: JIRA_USER and JIRA_TOKEN must be set"
    echo ""
    echo "To set them:"
    echo "  export JIRA_USER=your.email@company.com"
    echo "  export JIRA_TOKEN=your-api-token"
    echo ""
    echo "To get an API token:"
    echo "  1. Go to your Jira profile"
    echo "  2. Security -> API tokens"
    echo "  3. Create new token"
    exit 1
fi

# Find the latest change file
CHANGE_FILE=$(ls -t /tmp/k8s-changes-*.yaml 2>/dev/null | head -1)
MANIFEST_FILE=$(ls -t /tmp/k8s-final-manifests-*.yaml 2>/dev/null | head -1)

if [ -z "$CHANGE_FILE" ]; then
    echo "Warning: No change file found in /tmp/"
fi

if [ -z "$MANIFEST_FILE" ]; then
    echo "Warning: No manifest file found in /tmp/"
fi

# Get cluster context
CURRENT_CONTEXT=$(kubectl config current-context 2>/dev/null || echo "unknown")
CURRENT_NAMESPACE=$(kubectl config view --minify -o jsonpath='{..namespace}' || echo "default")

echo "Updating Jira ticket: $TICKET_ID"
echo "  Context: $CURRENT_CONTEXT"
echo "  Namespace: $CURRENT_NAMESPACE"
echo "  Change file: ${CHANGE_FILE:-none}"
echo "  Manifest file: ${MANIFEST_FILE:-none}"
echo ""

# Call Python script
python3 "$(dirname "$0")/jira_integration.py" \
    "$TICKET_ID" \
    ${CHANGE_FILE:+--change-file "$CHANGE_FILE"} \
    ${MANIFEST_FILE:+--manifest-file "$MANIFEST_FILE"} \
    --cluster "$CURRENT_CONTEXT" \
    --environment "${K8S_ENVIRONMENT:-$CURRENT_NAMESPACE}" \
    "$@"

echo ""
echo "✓ Jira ticket updated successfully"
