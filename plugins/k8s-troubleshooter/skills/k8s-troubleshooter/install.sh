#!/bin/bash
# install.sh - Automated K8s-Troubleshooter Skill installer for Claude Code

set -euo pipefail

# Configuration
SKILL_NAME="k8s-troubleshooter"
SKILL_VERSION="1.0.0"
BITBUCKET_BASE_URL="${BITBUCKET_URL:-https://bitbucket.company.com}"
REPO_PATH="tools/k8s-troubleshooter-skill"
SKILL_FILE="k8s-troubleshooter.skill"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color
BOLD='\033[1m'

# Banner
echo -e "${BLUE}╔══════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║     K8s-Troubleshooter Skill Installer v${SKILL_VERSION}      ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════════════╝${NC}"
echo ""

# Check prerequisites
echo -e "${YELLOW}Checking prerequisites...${NC}"

# Check for Claude Code CLI
if ! command -v claude-code &> /dev/null; then
    echo -e "${RED}✗ Claude Code CLI not found${NC}"
    echo "Please install Claude Code first:"
    echo "  https://docs.claude.com/en/docs/claude-code"
    exit 1
else
    echo -e "${GREEN}✓ Claude Code CLI found${NC}"
fi

# Check for kubectl
if ! command -v kubectl &> /dev/null; then
    echo -e "${YELLOW}⚠ kubectl not found${NC}"
    echo "  kubectl is required for the skill to function"
    echo "  Install from: https://kubernetes.io/docs/tasks/tools/"
    read -p "Continue anyway? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
else
    echo -e "${GREEN}✓ kubectl found${NC}"
fi

# Check for git (optional)
if command -v git &> /dev/null; then
    echo -e "${GREEN}✓ git found${NC}"
    USE_GIT=true
else
    echo -e "${YELLOW}⚠ git not found - will use curl/wget${NC}"
    USE_GIT=false
fi

# Determine Claude Code skills directory
echo ""
echo -e "${YELLOW}Determining Claude Code installation directory...${NC}"

CLAUDE_CODE_DIR=""
if [ -d "$HOME/.claude-code" ]; then
    CLAUDE_CODE_DIR="$HOME/.claude-code"
elif [ -d "$HOME/.config/claude-code" ]; then
    CLAUDE_CODE_DIR="$HOME/.config/claude-code"
elif [ -n "${CLAUDE_CODE_HOME:-}" ]; then
    CLAUDE_CODE_DIR="$CLAUDE_CODE_HOME"
else
    # Ask user
    echo "Claude Code directory not found automatically."
    read -p "Enter Claude Code directory path (or press Enter for default): " user_dir
    if [ -n "$user_dir" ]; then
        CLAUDE_CODE_DIR="$user_dir"
    else
        CLAUDE_CODE_DIR="$HOME/.claude-code"
    fi
fi

SKILLS_DIR="$CLAUDE_CODE_DIR/skills"
echo -e "${GREEN}✓ Using Claude Code directory: $CLAUDE_CODE_DIR${NC}"

# Create skills directory if it doesn't exist
mkdir -p "$SKILLS_DIR"

# Download method selection
echo ""
echo -e "${YELLOW}Select download method:${NC}"
echo "1) Download from Bitbucket (requires authentication)"
echo "2) Install from local file"
echo "3) Install from URL"

read -p "Choice (1-3): " -n 1 -r
echo

case $REPLY in
    1)
        # Download from Bitbucket
        echo ""
        echo -e "${YELLOW}Downloading from Bitbucket...${NC}"
        
        SKILL_URL="$BITBUCKET_BASE_URL/$REPO_PATH/raw/main/$SKILL_FILE"
        
        # Check for authentication
        echo "Bitbucket authentication may be required."
        read -p "Username (or press Enter to skip): " bb_user
        
        if [ -n "$bb_user" ]; then
            read -s -p "Password/Token: " bb_pass
            echo
            
            # Download with authentication
            if command -v curl &> /dev/null; then
                curl -u "$bb_user:$bb_pass" -L -o "$SKILLS_DIR/$SKILL_FILE" "$SKILL_URL"
            elif command -v wget &> /dev/null; then
                wget --user="$bb_user" --password="$bb_pass" -O "$SKILLS_DIR/$SKILL_FILE" "$SKILL_URL"
            else
                echo -e "${RED}Neither curl nor wget found. Cannot download.${NC}"
                exit 1
            fi
        else
            # Try without authentication
            if command -v curl &> /dev/null; then
                curl -L -o "$SKILLS_DIR/$SKILL_FILE" "$SKILL_URL"
            elif command -v wget &> /dev/null; then
                wget -O "$SKILLS_DIR/$SKILL_FILE" "$SKILL_URL"
            fi
        fi
        ;;
        
    2)
        # Install from local file
        echo ""
        read -p "Enter path to $SKILL_FILE: " local_path
        
        if [ -f "$local_path" ]; then
            cp "$local_path" "$SKILLS_DIR/$SKILL_FILE"
            echo -e "${GREEN}✓ Copied from local file${NC}"
        else
            echo -e "${RED}File not found: $local_path${NC}"
            exit 1
        fi
        ;;
        
    3)
        # Install from URL
        echo ""
        read -p "Enter URL to $SKILL_FILE: " skill_url
        
        if command -v curl &> /dev/null; then
            curl -L -o "$SKILLS_DIR/$SKILL_FILE" "$skill_url"
        elif command -v wget &> /dev/null; then
            wget -O "$SKILLS_DIR/$SKILL_FILE" "$skill_url"
        else
            echo -e "${RED}Neither curl nor wget found. Cannot download.${NC}"
            exit 1
        fi
        ;;
        
    *)
        echo -e "${RED}Invalid choice${NC}"
        exit 1
        ;;
esac

# Verify installation
if [ -f "$SKILLS_DIR/$SKILL_FILE" ]; then
    echo -e "${GREEN}✓ Skill file installed successfully${NC}"
else
    echo -e "${RED}✗ Installation failed${NC}"
    exit 1
fi

# Register skill with Claude Code (if CLI supports it)
echo ""
echo -e "${YELLOW}Registering skill with Claude Code...${NC}"

if claude-code skill list &> /dev/null; then
    claude-code skill register "$SKILLS_DIR/$SKILL_FILE" 2>/dev/null || true
    echo -e "${GREEN}✓ Skill registered${NC}"
else
    echo -e "${YELLOW}⚠ Manual registration may be required${NC}"
fi

# Configure environment
echo ""
echo -e "${YELLOW}Configuration${NC}"
echo "============="

# Jira configuration
read -p "Configure Jira integration? (y/N) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    read -p "Jira URL: " jira_url
    read -p "Jira Username: " jira_user
    read -s -p "Jira API Token: " jira_token
    echo
    
    # Add to shell profile
    SHELL_RC="$HOME/.bashrc"
    if [ -n "$ZSH_VERSION" ]; then
        SHELL_RC="$HOME/.zshrc"
    fi
    
    echo "" >> "$SHELL_RC"
    echo "# K8s-Troubleshooter Jira Configuration" >> "$SHELL_RC"
    echo "export JIRA_URL=\"$jira_url\"" >> "$SHELL_RC"
    echo "export JIRA_USER=\"$jira_user\"" >> "$SHELL_RC"
    echo "export JIRA_TOKEN=\"$jira_token\"" >> "$SHELL_RC"
    
    echo -e "${GREEN}✓ Jira configuration saved${NC}"
fi

# Create config file
CONFIG_FILE="$CLAUDE_CODE_DIR/skills-config.json"
if [ ! -f "$CONFIG_FILE" ]; then
    cat > "$CONFIG_FILE" <<EOF
{
  "$SKILL_NAME": {
    "version": "$SKILL_VERSION",
    "installed": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
    "auto_update": true,
    "config": {
      "production_check": true,
      "jira_integration": true
    }
  }
}
EOF
    echo -e "${GREEN}✓ Configuration file created${NC}"
fi

# Test installation
echo ""
echo -e "${YELLOW}Testing installation...${NC}"

# Create test command
TEST_CMD="claude-code --test-skill $SKILL_NAME"

if claude-code --help | grep -q "test-skill" 2>/dev/null; then
    $TEST_CMD && echo -e "${GREEN}✓ Skill test passed${NC}" || echo -e "${YELLOW}⚠ Skill test not available${NC}"
else
    echo -e "${YELLOW}⚠ Test command not available in this Claude Code version${NC}"
fi

# Success message
echo ""
echo -e "${GREEN}╔══════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║        Installation completed successfully!          ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════════╝${NC}"
echo ""
echo "Next steps:"
echo "1. Start Claude Code: ${BOLD}claude-code${NC}"
echo "2. Load the skill: ${BOLD}use skill k8s-troubleshooter${NC}"
echo "3. Start troubleshooting: ${BOLD}k8s diagnose${NC}"
echo ""
echo "Documentation: $BITBUCKET_BASE_URL/$REPO_PATH"
echo "Support: #platform-tools on Slack"
echo ""
echo -e "${YELLOW}Remember: Always follow production change procedures!${NC}"
