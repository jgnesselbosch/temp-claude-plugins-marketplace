#!/bin/bash
# init_session.sh - Initialize K8s troubleshooting session with temp directory and change tracking

set -euo pipefail

# Get Jira ticket from argument or use NO-TICKET
JIRA_TICKET="${1:-NO-TICKET}"

# Create dedicated temp directory for session
SESSION_DIR="/tmp/k8s-troubleshooter/$(date +%Y%m%d-%H%M%S)-${JIRA_TICKET}"
mkdir -p "$SESSION_DIR"

# Initialize change tracking file
CHANGE_FILE="$SESSION_DIR/k8s-changes.yaml"
cat > "$CHANGE_FILE" << EOF
Kubernetes Changes - Session $(date)
Ticket: ${JIRA_TICKET}
Cluster: $(kubectl config current-context)
Date: $(date)
EOF

# Export variables for use in current shell (must be sourced)
export SESSION_DIR
export CHANGE_FILE
export JIRA_TICKET

echo "✅ Session directory created: $SESSION_DIR"
echo "✅ Change tracking file: $CHANGE_FILE"
echo ""
echo "Environment variables set:"
echo "  SESSION_DIR=$SESSION_DIR"
echo "  CHANGE_FILE=$CHANGE_FILE"
echo "  JIRA_TICKET=$JIRA_TICKET"
echo ""
echo "Note: Source this script to export variables to your shell:"
echo "  source scripts/init_session.sh [TICKET-ID]"
