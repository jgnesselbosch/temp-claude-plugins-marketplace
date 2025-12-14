#!/bin/bash
# update_knowledge_base.sh - Update the skill's knowledge base with learnings from sessions

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(dirname "$SCRIPT_DIR")"

# Use ~/.claude for knowledge base (NOT the git repo!)
# This is where the skill is actually installed and used
CLAUDE_HOME="${CLAUDE_HOME:-$HOME/.claude}"
KB_DIR="${CLAUDE_HOME}/skills/k8s-troubleshooter"
KB_FILE="${KB_DIR}/session-knowledge.md"

# Create KB directory if it doesn't exist
mkdir -p "$KB_DIR"

SESSION_DIR="${SESSION_DIR:-/tmp}"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=========================================${NC}"
echo -e "${BLUE}  Knowledge Base Update${NC}"
echo -e "${BLUE}=========================================${NC}"
echo ""

# Check if we have Python
if ! command -v python3 &> /dev/null; then
    echo -e "${YELLOW}Python3 not found. Skipping knowledge base update.${NC}"
    exit 0
fi

# Check if extract_learnings.py exists
EXTRACTOR="${SCRIPT_DIR}/extract_learnings.py"
if [ ! -f "$EXTRACTOR" ]; then
    echo -e "${YELLOW}Learning extractor not found at: $EXTRACTOR${NC}"
    echo "Skipping knowledge base update."
    exit 0
fi

# Count available sessions
SESSION_COUNT=$(ls -1 "${SESSION_DIR}"/k8s-session-summary-*.txt 2>/dev/null | wc -l)

if [ "$SESSION_COUNT" -eq 0 ]; then
    echo -e "${YELLOW}No session summaries found in ${SESSION_DIR}${NC}"
    echo "Nothing to learn from yet."
    exit 0
fi

echo "Found ${SESSION_COUNT} session(s) to analyze"
echo ""

# Run the extractor
echo "Extracting learnings..."
if python3 "$EXTRACTOR" "$SESSION_DIR" "$KB_FILE"; then
    echo ""
    echo -e "${GREEN}✓ Knowledge base updated successfully!${NC}"
    echo ""
    echo "Updated file: $KB_FILE"
    echo ""
    echo -e "${YELLOW}The skill will now reference these learnings in future troubleshooting sessions.${NC}"
    
    # Show quick stats
    if [ -f "$KB_FILE" ]; then
        PROBLEM_TYPES=$(grep -c "^### " "$KB_FILE" || echo "0")
        echo ""
        echo "Knowledge Base Stats:"
        echo "  - Problem patterns identified: $PROBLEM_TYPES"
        echo "  - Sessions analyzed: $SESSION_COUNT"
    fi
else
    echo -e "${YELLOW}Warning: Knowledge base update encountered issues${NC}"
    exit 1
fi

echo ""
echo -e "${GREEN}Knowledge base update complete.${NC}"
echo ""
echo "Knowledge base location: $KB_FILE"
echo ""
echo -e "${YELLOW}Tip: View your knowledge base anytime with:${NC}"
echo "  cat $KB_FILE"
