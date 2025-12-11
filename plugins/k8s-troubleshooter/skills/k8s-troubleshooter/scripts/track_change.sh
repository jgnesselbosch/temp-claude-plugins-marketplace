#!/bin/bash
# track_change.sh - Track Kubernetes changes in declarative YAML format

CHANGE_FILE="${CHANGE_FILE:-/tmp/k8s-changes-$(date +%Y%m%d-%H%M%S).yaml}"
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

track_change() {
    local resource_type="$1"
    local resource_name="$2"
    local namespace="$3"
    local operation="$4"
    local manifest="$5"
    
    # Add separator and metadata
    cat >> "$CHANGE_FILE" <<EOF
---
# Change tracked at: $TIMESTAMP
# Operation: $operation
# Resource: $resource_type/$resource_name
# Namespace: $namespace
# Jira Ticket: ${JIRA_TICKET:-"NOT_SET"}
EOF
    
    # Append the actual manifest
    echo "$manifest" >> "$CHANGE_FILE"
    
    echo "Change tracked in: $CHANGE_FILE"
}

# If called with arguments, track the change
if [ $# -eq 5 ]; then
    track_change "$@"
else
    echo "Usage: $0 <resource_type> <resource_name> <namespace> <operation> <manifest>"
    echo "Current change file: $CHANGE_FILE"
fi

export -f track_change
export CHANGE_FILE
