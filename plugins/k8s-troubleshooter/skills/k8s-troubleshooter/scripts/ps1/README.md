# PowerShell Scripts for K8s-Troubleshooter

Windows/PowerShell equivalents of the Bash scripts for Kubernetes troubleshooting.

## Available Scripts

### Test-K8sProductionEnv.ps1
Checks for production environment and requires explicit confirmation before proceeding.

**Usage:**
```powershell
# Run production check (interactive)
.\Test-K8sProductionEnv.ps1

# Skip confirmation (use with caution!)
.\Test-K8sProductionEnv.ps1 -SkipConfirmation
```

**Features:**
- Detects production environments by checking context, namespace, and cluster URL
- Requires explicit confirmation with format: `CONFIRM-PROD-CHANGES-TICKET-ID`
- Logs all production access attempts to `$env:TEMP\k8s-prod-access-YYYYMMDD.log`
- Sets environment variables for session tracking
- Works in non-production environments with optional ticket ID

**Production Indicators:**
The script checks for these keywords in context, namespace, and cluster URL:
- `prod`
- `production`
- `prd`
- `live`
- `master`

**Environment Variables Set:**
- `$env:JIRA_TICKET`: Ticket ID from confirmation
- `$env:PRODUCTION_CONFIRMED`: "true" if production access confirmed
- `$env:PRODUCTION_CONFIRMATION_TIME`: UTC timestamp of confirmation
- `$env:K8S_ENVIRONMENT_TYPE`: "production" or "development"

---

### Get-K8sHealth.ps1
Performs comprehensive health check of Kubernetes cluster.

**Usage:**
```powershell
# Basic health check for default namespace
.\Get-K8sHealth.ps1

# Detailed check for specific namespace
.\Get-K8sHealth.ps1 -Namespace my-namespace -Detailed

# Save report to file
.\Get-K8sHealth.ps1 -Namespace my-namespace -OutputFile report.json
```

**Parameters:**
- `-Namespace`: Target namespace (default: "default")
- `-Detailed`: Show detailed node and event information
- `-OutputFile`: Save JSON report to specified file

---

### Track-K8sChange.ps1
Tracks Kubernetes changes in declarative YAML format.

**Usage:**
```powershell
# Track a change (typically called by Apply-K8sWithTracking.ps1)
.\Track-K8sChange.ps1 -ResourceType deployment `
                      -ResourceName my-app `
                      -Namespace default `
                      -Operation UPDATE `
                      -Manifest $yamlContent
```

**Parameters:**
- `-ResourceType`: Type of resource (e.g., deployment, service)
- `-ResourceName`: Name of the resource
- `-Namespace`: Kubernetes namespace
- `-Operation`: CREATE, UPDATE, DELETE, or PATCH
- `-Manifest`: YAML manifest content as string

**Environment Variables:**
- `$env:K8S_CHANGE_FILE`: Path to session change tracking file (auto-created if not set)
- `$env:JIRA_TICKET`: Jira ticket ID for tracking

---

### Show-K8sChanges.ps1
Displays all tracked changes from current session.

**Usage:**
```powershell
# Show changes from current session
.\Show-K8sChanges.ps1

# Show changes from specific file
.\Show-K8sChanges.ps1 -ChangeFile "C:\Temp\k8s-changes-20231208-143022.yaml"
```

**Parameters:**
- `-ChangeFile`: (Optional) Specific change file to display

**Output includes:**
- Total number of changes
- Affected namespaces
- Modified resource types
- Complete YAML manifests
- Git commit instructions
- Rollback information

---

### Apply-K8sWithTracking.ps1
Applies Kubernetes manifests with automatic change tracking.

**Usage:**
```powershell
# Apply a manifest file with tracking
.\Apply-K8sWithTracking.ps1 -ManifestFile deployment.yaml
```

**Parameters:**
- `-ManifestFile`: Path to YAML manifest file

**Features:**
- Automatically detects CREATE vs UPDATE operations
- Backs up existing resources before updates
- Tracks all changes in session file
- Verifies resource state after apply

**Prerequisites:**
- kubectl must be installed and configured
- Manifest file must be valid Kubernetes YAML

---

## Environment Setup

### Session Initialization

```powershell
# Set up change tracking for session
$env:K8S_CHANGE_FILE = "$env:TEMP\k8s-changes-$(Get-Date -Format 'yyyyMMdd-HHmmss').yaml"
$env:JIRA_TICKET = "PROJECT-12345"

# Verify kubectl access
kubectl cluster-info
kubectl config get-contexts
```

### Jira Integration

```powershell
# Configure Jira credentials (add to PowerShell profile)
$env:JIRA_URL = "https://jira.company.com"
$env:JIRA_USER = "your.email@company.com"
$env:JIRA_TOKEN = "your-api-token"
```

---

## Complete Workflow Example

```powershell
# 1. Production environment check (CRITICAL - Always run first!)
.\Test-K8sProductionEnv.ps1

# 2. Initialize session
$env:K8S_CHANGE_FILE = "$env:TEMP\k8s-changes-$(Get-Date -Format 'yyyyMMdd-HHmmss').yaml"
# Note: $env:JIRA_TICKET is set by Test-K8sProductionEnv.ps1 if production

# 3. Check cluster health
.\Get-K8sHealth.ps1 -Namespace production -Detailed

# 3. Apply changes with tracking
.\Apply-K8sWithTracking.ps1 -ManifestFile deployment.yaml
.\Apply-K8sWithTracking.ps1 -ManifestFile service.yaml

# 4. Review all changes
.\Show-K8sChanges.ps1

# 5. Commit to Git
git add $env:K8S_CHANGE_FILE
git commit -m "K8s changes for $env:JIRA_TICKET"
git push origin feature/$env:JIRA_TICKET
```

---

## Differences from Bash Scripts

### Path Handling
- **Bash**: Uses `/tmp/` for temporary files
- **PowerShell**: Uses `$env:TEMP` (typically `C:\Users\<user>\AppData\Local\Temp`)

### Environment Variables
- **Bash**: `$CHANGE_FILE`, `$JIRA_TICKET`
- **PowerShell**: `$env:K8S_CHANGE_FILE`, `$env:JIRA_TICKET`

### Line Endings
- PowerShell scripts use UTF-8 encoding with CRLF line endings
- Output YAML files use UTF-8 encoding for compatibility

### Date Formatting
- **Bash**: `date +%Y%m%d-%H%M%S`
- **PowerShell**: `Get-Date -Format 'yyyyMMdd-HHmmss'`

---

## Troubleshooting

### kubectl not found
```powershell
# Add kubectl to PATH or use full path
$env:PATH += ";C:\path\to\kubectl"
```

### Change file not found
```powershell
# List recent change files
Get-ChildItem $env:TEMP -Filter "k8s-changes-*.yaml" | Sort-Object LastWriteTime -Descending
```

### Permission errors
```powershell
# Run PowerShell as Administrator if needed
# Or check execution policy
Get-ExecutionPolicy
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

---

## Installation

Run the installation script from the skill root directory:

```powershell
.\Install-K8sTroubleshooter.ps1
```

This will:
- Check prerequisites (kubectl, git)
- Install skill files to Claude Code directory
- Configure Jira integration (optional)
- Create skill configuration file

---

## Support

For issues or questions:
- Check main SKILL.md documentation
- Review bash script equivalents in parent `scripts/` directory
- Contact platform team on Slack: #platform-tools
