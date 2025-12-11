#!/bin/bash
# finalize_session.sh - Generate final manifest collection and summary

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}=========================================${NC}"
echo -e "${GREEN}  Kubernetes Session Finalization${NC}"
echo -e "${GREEN}=========================================${NC}"
echo ""

# Find change file
if [ -z "${CHANGE_FILE:-}" ]; then
    CHANGE_FILE=$(ls -t /tmp/k8s-changes-*.yaml 2>/dev/null | head -1)
fi

if [ -z "$CHANGE_FILE" ] || [ ! -f "$CHANGE_FILE" ]; then
    echo -e "${YELLOW}No changes were tracked in this session.${NC}"
    exit 0
fi

# Generate summary file
SUMMARY_FILE="/tmp/k8s-session-summary-$(date +%Y%m%d-%H%M%S).txt"
MANIFEST_FILE="/tmp/k8s-final-manifests-$(date +%Y%m%d-%H%M%S).yaml"

# Create summary header
cat > "$SUMMARY_FILE" <<EOF
Kubernetes Troubleshooting Session Summary
==========================================
Date: $(date)
Jira Ticket: ${JIRA_TICKET:-"Not specified"}
Change File: $CHANGE_FILE
Final Manifests: $MANIFEST_FILE

Statistics:
-----------
EOF

# Calculate statistics
TOTAL_CHANGES=$(grep -c "^---$" "$CHANGE_FILE" || echo "0")
echo "Total Changes: $TOTAL_CHANGES" >> "$SUMMARY_FILE"

# Extract namespaces
NAMESPACES=$(grep "# Namespace:" "$CHANGE_FILE" | cut -d':' -f2 | sort -u | xargs)
echo "Affected Namespaces: $NAMESPACES" >> "$SUMMARY_FILE"

# Count by operation type
CREATES=$(grep -c "# Operation: CREATE" "$CHANGE_FILE" || echo "0")
UPDATES=$(grep -c "# Operation: UPDATE" "$CHANGE_FILE" || echo "0")
DELETES=$(grep -c "# Operation: DELETE" "$CHANGE_FILE" || echo "0")

echo "  - Creates: $CREATES" >> "$SUMMARY_FILE"
echo "  - Updates: $UPDATES" >> "$SUMMARY_FILE"
echo "  - Deletes: $DELETES" >> "$SUMMARY_FILE"

# Resource type breakdown
echo "" >> "$SUMMARY_FILE"
echo "Resource Types Modified:" >> "$SUMMARY_FILE"
grep "# Resource:" "$CHANGE_FILE" | cut -d':' -f2 | cut -d'/' -f1 | sort | uniq -c | \
    while read count type; do
        echo "  - $type: $count" >> "$SUMMARY_FILE"
    done

# Create consolidated manifest file
echo "---" > "$MANIFEST_FILE"
echo "# Consolidated Kubernetes Manifests" >> "$MANIFEST_FILE"
echo "# Generated: $(date)" >> "$MANIFEST_FILE"
echo "# Jira Ticket: ${JIRA_TICKET:-"Not specified"}" >> "$MANIFEST_FILE"
echo "# Total Changes: $TOTAL_CHANGES" >> "$MANIFEST_FILE"
echo "" >> "$MANIFEST_FILE"

# Process and clean manifests
grep -v "^#" "$CHANGE_FILE" >> "$MANIFEST_FILE"

# Validate YAML
echo ""
echo -e "${YELLOW}Validating final manifests...${NC}"
if command -v yamllint >/dev/null 2>&1; then
    if yamllint -d relaxed "$MANIFEST_FILE" 2>/dev/null; then
        echo -e "${GREEN}✓ YAML validation passed${NC}"
    else
        echo -e "${YELLOW}⚠ YAML validation warnings (review before applying)${NC}"
    fi
else
    echo "yamllint not installed, skipping validation"
fi

# Create rollback script
ROLLBACK_SCRIPT="/tmp/k8s-rollback-$(date +%Y%m%d-%H%M%S).sh"
cat > "$ROLLBACK_SCRIPT" <<'EOF'
#!/bin/bash
# Rollback script for this session's changes
echo "Rolling back Kubernetes changes..."

# Apply backup files in reverse order
for backup in $(ls -t /tmp/backup-*.yaml); do
    echo "Applying $backup"
    kubectl apply -f "$backup"
done

echo "Rollback complete. Verify cluster state."
EOF
chmod +x "$ROLLBACK_SCRIPT"

# Display summary
echo ""
echo -e "${GREEN}Session Summary:${NC}"
echo "================"
cat "$SUMMARY_FILE"

echo ""
echo -e "${GREEN}Generated Files:${NC}"
echo "================"
echo "1. Summary: $SUMMARY_FILE"
echo "2. Final Manifests: $MANIFEST_FILE"
echo "3. Rollback Script: $ROLLBACK_SCRIPT"
echo "4. Change Log: $CHANGE_FILE"

echo ""
echo -e "${YELLOW}⚠️  WICHTIGE NÄCHSTE SCHRITTE:${NC}"
echo "================================"
echo "1. Review final manifests:"
echo "   cat $MANIFEST_FILE"
echo ""
echo "2. Commit to Git repository:"
echo "   git checkout -b feature/${JIRA_TICKET:-TICKET-ID}"
echo "   cp $MANIFEST_FILE ./k8s/changes/"
echo "   git add ./k8s/changes/"
echo "   git commit -m \"K8s fixes for ${JIRA_TICKET:-TICKET-ID}\""
echo "   git push origin feature/${JIRA_TICKET:-TICKET-ID}"
echo ""
echo "3. Update Jira ticket:"
echo "   scripts/update_jira.sh ${JIRA_TICKET:-TICKET-ID}"
echo ""
echo "4. If rollback needed:"
echo "   bash $ROLLBACK_SCRIPT"
echo ""
echo -e "${RED}⚠️  CRITICAL: Diese Änderungen MÜSSEN ins Git-Repository (Bitbucket) eingepflegt werden!${NC}"
echo -e "${RED}   Dies ist essentiell für die GitOps-Compliance und Nachvollziehbarkeit!${NC}"
echo ""
echo -e "${GREEN}Session erfolgreich abgeschlossen.${NC}"
