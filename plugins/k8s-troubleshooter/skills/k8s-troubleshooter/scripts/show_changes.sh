#!/bin/bash
# show_changes.sh - Display all Kubernetes changes from current session

set -euo pipefail

# Find the most recent change file or use environment variable
if [ -z "${CHANGE_FILE:-}" ]; then
    CHANGE_FILE=$(ls -t /tmp/k8s-changes-*.yaml 2>/dev/null | head -1)
fi

if [ -z "$CHANGE_FILE" ] || [ ! -f "$CHANGE_FILE" ]; then
    echo "No changes tracked in this session."
    echo "Start tracking changes by using apply_with_tracking.sh"
    exit 0
fi

echo "========================================="
echo "  Kubernetes Session Changes Summary"
echo "========================================="
echo ""
echo "Session file: $CHANGE_FILE"
echo "Jira Ticket: ${JIRA_TICKET:-"Not set - Please set JIRA_TICKET environment variable"}"
echo ""

# Count changes
TOTAL_CHANGES=$(grep -c "^---$" "$CHANGE_FILE" || true)
echo "Total changes tracked: $TOTAL_CHANGES"

# Extract unique namespaces
NAMESPACES=$(grep "# Namespace:" "$CHANGE_FILE" | cut -d':' -f2 | sort -u | tr '\n' ', ' | sed 's/,$//')
echo "Affected namespaces: $NAMESPACES"

# Extract resource types
RESOURCES=$(grep "# Resource:" "$CHANGE_FILE" | cut -d':' -f2 | cut -d'/' -f1 | sort -u | tr '\n' ', ' | sed 's/,$//')
echo "Modified resource types: $RESOURCES"

echo ""
echo "========================================="
echo "  Declarative YAML Manifests"
echo "========================================="
echo ""

# Display the complete YAML with syntax validation
if command -v yamllint >/dev/null 2>&1; then
    echo "Validating YAML syntax..."
    if yamllint -d relaxed "$CHANGE_FILE" 2>/dev/null; then
        echo "✓ YAML validation passed"
    else
        echo "⚠ YAML validation warnings (non-critical)"
    fi
    echo ""
fi

# Display the changes
cat "$CHANGE_FILE"

echo ""
echo "========================================="
echo "  Next Steps"
echo "========================================="
echo ""
echo "1. Review the changes above"
echo "2. Save manifests to Git repository:"
echo "   git add $CHANGE_FILE"
echo "   git commit -m \"K8s changes for ${JIRA_TICKET:-TICKET-ID}\""
echo "   git push origin feature/${JIRA_TICKET:-TICKET-ID}"
echo ""
echo "3. To apply all changes at once:"
echo "   kubectl apply -f $CHANGE_FILE"
echo ""
echo "4. To rollback changes, use backup files in /tmp/backup-*"
echo ""
echo "⚠️  WICHTIG: Diese Änderungen müssen ins Git-Repository (Bitbucket) eingepflegt werden!"
