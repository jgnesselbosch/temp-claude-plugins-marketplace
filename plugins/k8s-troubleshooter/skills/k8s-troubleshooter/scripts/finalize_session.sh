#!/bin/bash
# finalize_session.sh - Generate final manifest collection and summary

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${GREEN}=========================================${NC}"
echo -e "${GREEN}  Kubernetes Session Finalization${NC}"
echo -e "${GREEN}=========================================${NC}"
echo ""

# Find session directory and change file
if [ -z "${SESSION_DIR:-}" ]; then
    # Try to find most recent session directory
    SESSION_DIR=$(ls -dt /tmp/k8s-troubleshooter/*/ 2>/dev/null | head -1 | sed 's:/$::')
fi

if [ -z "${SESSION_DIR:-}" ] || [ ! -d "$SESSION_DIR" ]; then
    echo -e "${YELLOW}No session directory found.${NC}"
    echo "Expected: /tmp/k8s-troubleshooter/YYYYMMDD-HHMMSS-TICKET/"
    exit 0
fi

# Find change file in session directory
if [ -z "${CHANGE_FILE:-}" ]; then
    CHANGE_FILE="$SESSION_DIR/k8s-changes.yaml"
fi

if [ ! -f "$CHANGE_FILE" ]; then
    echo -e "${YELLOW}No changes were tracked in this session.${NC}"
    echo "Session directory: $SESSION_DIR"
    exit 0
fi

# Generate summary file in SESSION_DIR (not /tmp root)
SUMMARY_FILE="$SESSION_DIR/k8s-session-summary.txt"
MANIFEST_FILE="$SESSION_DIR/k8s-final-manifests.yaml"
ROLLBACK_SCRIPT="$SESSION_DIR/k8s-rollback.sh"

# Check if files already exist (avoid overwriting)
SKIP_SUMMARY_GEN=false
if [ -f "$SUMMARY_FILE" ]; then
    echo -e "${YELLOW}Summary file already exists: $SUMMARY_FILE${NC}"
    echo "Using existing summary. To regenerate, delete the file first."
    cat "$SUMMARY_FILE"
    SKIP_SUMMARY_GEN=true
fi

# Create summary header (only if not skipping)
if [ "$SKIP_SUMMARY_GEN" = false ]; then
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

fi  # End of SKIP_SUMMARY_GEN check

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

# Create rollback script (only if backups exist and script doesn't exist)
if [ ! -f "$ROLLBACK_SCRIPT" ]; then
    if ls "$SESSION_DIR"/backup-*.yaml 1> /dev/null 2>&1; then
        cat > "$ROLLBACK_SCRIPT" <<EOF
#!/bin/bash
# Rollback script for this session's changes
# Session: $SESSION_DIR
echo "Rolling back Kubernetes changes..."

# Apply backup files in reverse order from this session
for backup in \$(ls -t "$SESSION_DIR"/backup-*.yaml 2>/dev/null); do
    echo "Applying \$backup"
    kubectl apply -f "\$backup"
done

echo "Rollback complete. Verify cluster state."
EOF
        chmod +x "$ROLLBACK_SCRIPT"
    else
        # No backups found, create a placeholder
        ROLLBACK_SCRIPT="$SESSION_DIR/no-rollback-needed.txt"
        echo "No backup files created - no rollback needed." > "$ROLLBACK_SCRIPT"
    fi
fi

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

# Copy summary to /tmp for knowledge base update (update_knowledge_base.sh expects files there)
if [ -f "$SUMMARY_FILE" ]; then
    TIMESTAMP=$(basename "$SESSION_DIR" | cut -d'-' -f1,2)
    TICKET=$(basename "$SESSION_DIR" | cut -d'-' -f3)
    KB_SUMMARY="/tmp/k8s-session-summary-${TIMESTAMP}-${TICKET}.txt"

    # Only copy if not already there
    if [ ! -f "$KB_SUMMARY" ]; then
        cp "$SUMMARY_FILE" "$KB_SUMMARY"
        echo ""
        echo -e "${BLUE}Session summary copied to: $KB_SUMMARY${NC}"
    fi
fi

if [ -z "${SKIP_KB_UPDATE:-}" ]; then
    echo ""
    echo -e "${BLUE}Updating knowledge base...${NC}"

    # Try to find update_knowledge_base.sh in multiple locations
    # SCRIPT_DIR is plugins/k8s-troubleshooter/skills/k8s-troubleshooter/scripts
    # We need plugins/k8s-troubleshooter/scripts/update_knowledge_base.sh
    KB_UPDATE_SCRIPT=""

    if [ -f "$SCRIPT_DIR/../../../scripts/update_knowledge_base.sh" ]; then
        KB_UPDATE_SCRIPT="$SCRIPT_DIR/../../../scripts/update_knowledge_base.sh"
    elif [ -f "$SCRIPT_DIR/../../scripts/update_knowledge_base.sh" ]; then
        KB_UPDATE_SCRIPT="$SCRIPT_DIR/../../scripts/update_knowledge_base.sh"
    fi

    if [ -n "$KB_UPDATE_SCRIPT" ]; then
        # Pass the parent directory of SESSION_DIR (e.g., /tmp/k8s-troubleshooter)
        SESSION_PARENT_DIR=$(dirname "$SESSION_DIR")
        SESSION_DIR="$SESSION_PARENT_DIR" bash "$KB_UPDATE_SCRIPT" || true
    else
        echo -e "${YELLOW}Knowledge base update script not found${NC}"
        echo "Looked in: $SCRIPT_DIR/../../../scripts/ and $SCRIPT_DIR/../../scripts/"
    fi
fi
