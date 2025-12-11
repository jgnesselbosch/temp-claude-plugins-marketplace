---
name: k8s-troubleshooter
description: Comprehensive Kubernetes cluster troubleshooting skill for interactive problem-solving with Claude Code. Handles debugging and fixes for pods, services, deployments, Tekton pipelines, Crossplane XRs, and ArgoCD applications across namespaces. Tracks all changes declaratively in YAML format, integrates with Jira for documentation, and ensures GitOps-compliant workflows. Use when debugging Kubernetes issues, fixing cluster problems, or needing systematic K8s troubleshooting with full change tracking.
---


# Kubernetes Troubleshooter

Interactive Kubernetes cluster troubleshooting skill with declarative change tracking for GitOps workflows.

**📖 AI Agent Resources:**
- **AI_MANIFEST_EDITING_GUIDE.md** - Detailed guide for AI agents on creating fixed Kubernetes manifests

## ⚠️ CRITICAL RULES - READ FIRST ⚠️

**NEVER DO THESE:**
1. ❌ NEVER create files in the current working directory (it's usually a git repo!)
2. ❌ NEVER use Write tool with paths like `C:\Users\...\dev\git\...`
3. ❌ NEVER create `k8s-changes-*.yaml`, `backup-*.yaml`, or `fixed-*.yaml` in working directory

**ALWAYS DO THESE:**
1. ✅ ALWAYS create a session temp directory FIRST: `/tmp/k8s-troubleshooter/YYYYMMDD-HHMMSS-TICKET/`
2. ✅ ALWAYS put ALL session files (changes, backups, manifests) in that temp directory
3. ✅ ALWAYS use the temp directory variable for all file operations
4. ✅ At session end, tell user where the temp directory is located
5. ✅ ALWAYS use Write tool to create fixed manifests (AI-driven, not manual editing)
6. ✅ ALWAYS clean Kubernetes metadata (resourceVersion, uid, status) from fixed manifests

**Quick Start Checklist:**
- [ ] Create session temp directory
- [ ] Set SESSION_DIR variable
- [ ] Initialize change tracking file in SESSION_DIR
- [ ] Reference AI_MANIFEST_EDITING_GUIDE.md for creating fixed manifests
- [ ] Only then start troubleshooting

## Core Workflow

### 1. Session Initialization

**MANDATORY START PROCEDURE - NEVER SKIP THIS!**

Always start by detecting the shell environment and initializing the session:

1. **DETECT SHELL ENVIRONMENT**:
   - Check the actual shell being used (not just the OS platform)
   - **PowerShell (recommended for Windows)**: Use PowerShell scripts from `scripts/ps1/`
   - **Bash (Linux/Mac/WSL)**: Use bash scripts from `scripts/`
   - **Git Bash on Windows**: NOT fully supported - use PowerShell instead
   - Detection method: Check `$PSVersionTable` (PowerShell) or `$SHELL` variable (bash)
   
   **Shell Detection Examples:**
   ```powershell
   # In PowerShell - this will work
   if ($PSVersionTable) { Write-Host "PowerShell detected" }
   ```
   ```bash
   # In Bash - check if it's a full environment
   if [ -n "$SHELL" ]; then 
     echo "Bash/shell detected: $SHELL"
     # On Windows with Git Bash, recommend PowerShell instead
     if [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "win32" ]]; then
       echo "⚠️  WARNING: Git Bash detected on Windows. PowerShell recommended for full compatibility."
     fi
   fi
   ```
   
   **Important Notes:**
   - Windows users: Use PowerShell (not Git Bash) for full script compatibility
   - Git Bash lacks tools like `jq`, proper `/tmp` handling, and full POSIX compliance
   - WSL (Windows Subsystem for Linux) with full bash is supported
   - When in doubt on Windows: prefer PowerShell scripts

2. **CRITICAL PRODUCTION CHECK** (Silent check - only warn if production detected):

   **For Bash shell (Linux/Mac/WSL only - NOT Git Bash):**
   ```bash
   scripts/check_production_env.sh
   ```

   **For PowerShell (recommended for all Windows users):**
   ```powershell
   .\scripts\ps1\Test-K8sProductionEnv.ps1
   ```
   
   **Note:** If you're on Windows with Git Bash, use the PowerShell script instead for reliable execution.

   If production environment detected, require EXPLICIT confirmation:
   ```
   ⚠️ WARNUNG: PRODUKTIVUMGEBUNG ERKANNT! ⚠️

   Dieser Skill darf NORMALERWEISE NICHT für direkte Änderungen
   an Produktivsystemen verwendet werden!

   Produktivänderungen sollten ausschließlich über:
   - Git-basierte CI/CD Pipelines
   - ArgoCD Sync
   - Approved Change Requests

   erfolgen.

   Bestätigen Sie explizit, dass Sie verstehen:
   - Direkte Produktivänderungen verstoßen gegen IAC-Prinzipien
   - Alle Änderungen müssen dokumentiert und reviewt werden
   - Sie tragen die volle Verantwortung für Produktivänderungen

   Eingabe "CONFIRM-PROD-CHANGES-<TICKET-ID>" zum Fortfahren:
   ```

3. **Jira ticket handling**:
   - For non-production (local/dev): Skip Jira ticket requirement
   - For production: REQUIRE Jira ticket ID (format: PROJECT-12345)
   - Used for change tracking and documentation

4. **Silently perform read-only cluster checks** (no user confirmation needed):
   - Check cluster access: `kubectl cluster-info`
   - Identify available contexts: `kubectl config get-contexts`
   - Read-only operations like `kubectl get`, `kubectl describe`, `kubectl logs` require NO user approval

5. **Initialize change tracking file and temp directory**:
   - **CRITICAL**: ALL session files (backups, changes, fixed manifests) MUST be created in temp directories, NEVER in the git repository!

   **For Bash shell (Linux/Mac/WSL - NOT Git Bash on Windows):**
   ```bash
   # Source the initialization script (exports SESSION_DIR, CHANGE_FILE, JIRA_TICKET)
   source scripts/init_session.sh [TICKET-ID]
   
   # Or if you prefer inline:
   # SESSION_DIR="/tmp/k8s-troubleshooter/$(date +%Y%m%d-%H%M%S)-${JIRA_TICKET:-NO-TICKET}"
   # mkdir -p "$SESSION_DIR"
   # CHANGE_FILE="$SESSION_DIR/k8s-changes.yaml"
   ```

   **For PowerShell (Windows or cross-platform pwsh):**
   ```powershell
   # Run the initialization script (sets $env:K8S_SESSION_DIR, $env:K8S_CHANGE_FILE, $env:JIRA_TICKET)
   .\scripts\ps1\Initialize-K8sSession.ps1 [TICKET-ID]
   
   # Or if you prefer inline:
   # $jiraTicket = "TICKET-ID"
   # $sessionDir = "$env:TEMP\k8s-troubleshooter\$(Get-Date -Format 'yyyyMMdd-HHmmss')-$jiraTicket"
   # New-Item -ItemType Directory -Path $sessionDir -Force | Out-Null
   # $env:K8S_SESSION_DIR = $sessionDir
   # $env:K8S_CHANGE_FILE = "$sessionDir\k8s-changes-$jiraTicket.yaml"
   ```

6. **IMPORTANT FILE PATH RULES:**

   **Examples of correct and incorrect paths:**
   - ✅ CORRECT: `/tmp/k8s-troubleshooter/20251208-164149-NO-TICKET/backup-deployment-nginx.yaml`
   - ✅ CORRECT: Write tool with path like `/tmp/k8s-troubleshooter/.../fixed-deployment.yaml`
   - ❌ WRONG: `backup-deployment-nginx.yaml` (relative path in working directory)
   - ❌ WRONG: `C:\Users\username\dev\git\repo\k8s-changes.yaml` (inside git repo!)
   - ❌ WRONG: Write tool with path containing `\dev\git\` or similar git repo indicators

   **Key principles:**
   - Store directory path and change file path in variables for session use
   - ALL backups, fixed manifests, and tracking files go in this session directory
   - Reason: Prevents accidental commits of session tracking files to git
   - At session end, user copies only the final change tracking file to their git repo if needed

### 2. Problem Discovery

Systematic approach to identify issues:

```bash
# Quick cluster health check
kubectl get nodes
kubectl top nodes
kubectl get events --all-namespaces --sort-by='.lastTimestamp' | tail -20

# Namespace-specific investigation
kubectl get all -n <namespace>
kubectl get events -n <namespace> --sort-by='.lastTimestamp'
```

For specific components:
- **Tekton**: See references/tekton-troubleshooting.md
- **Crossplane**: See references/crossplane-troubleshooting.md  
- **ArgoCD**: See references/argocd-troubleshooting.md

### 3. Change Management Protocol

**CRITICAL**: Every WRITE operation must be:
1. Discussed with user before execution (only for write operations like `kubectl apply`, `kubectl delete`, etc.)
2. Recorded in declarative YAML format
3. Appended to session change file in temp directory
4. Executable via `kubectl apply`

**READ operations require NO user confirmation**:
- `kubectl get`
- `kubectl describe`
- `kubectl logs`
- `kubectl top`
- `kubectl config view`
- Any cluster inspection command

**Use scripts for automatic change tracking:**
- Bash: `scripts/track_change.sh`
- PowerShell: `scripts/ps1/Track-K8sChange.ps1`

### 4. Making Changes

**CRITICAL: Use declarative approach ONLY!**

**IMPORTANT: Before creating any fixed manifests, read AI_MANIFEST_EDITING_GUIDE.md for detailed instructions on:**
- Which metadata fields to remove (resourceVersion, uid, status, etc.)
- How to clean Kubernetes YAML properly
- Common fix patterns and examples
- Complete workflow with validation checklist

**AI Agent Workflow (Claude Code):**

When Claude identifies a fix needed, follow this workflow:

1. **Backup current resource** to session temp directory
2. **AI creates fixed manifest** by:
   - Reading the backup YAML
   - Removing cluster-specific fields (resourceVersion, uid, creationTimestamp, status, etc.)
   - Applying the necessary fixes (image tags, resource limits, env vars, etc.)
   - Writing the fixed YAML to `$SESSION_DIR/fixed-<resource>-<name>.yaml` (bash) or `$env:K8S_SESSION_DIR\fixed-<resource>-<name>.yaml` (PowerShell)
3. **Apply with tracking** using the appropriate script

**Bash/Linux:**
```bash
# 1. Backup current state TO SESSION TEMP DIRECTORY
kubectl get <resource> <name> -n <namespace> -o yaml > "$SESSION_DIR/backup-<resource>-<name>.yaml"

# 2. AI Agent uses Write tool to create fixed manifest
# MANIFEST_PATH="$SESSION_DIR/fixed-<resource>-<name>.yaml"
# Content: cleaned YAML with fixes applied (remove resourceVersion, uid, etc.)

# 3. Apply change with tracking
scripts/apply_with_tracking.sh "$SESSION_DIR/fixed-<resource>-<name>.yaml"
```

**PowerShell/Windows:**
```powershell
# 1. Backup current state TO SESSION TEMP DIRECTORY
kubectl get <resource> <name> -n <namespace> -o yaml | Out-File -FilePath "$env:K8S_SESSION_DIR\backup-<resource>-<name>.yaml" -Encoding utf8

# 2. AI Agent uses Write tool to create fixed manifest
# $manifestPath = "$env:K8S_SESSION_DIR\fixed-<resource>-<name>.yaml"
# Content: cleaned YAML with fixes applied (remove resourceVersion, uid, etc.)

# 3. Apply change with tracking
.\scripts\ps1\Apply-K8sWithTracking.ps1 -ManifestFile "$env:K8S_SESSION_DIR\fixed-<resource>-<name>.yaml"
```

**Fields to ALWAYS remove from Kubernetes YAML when creating fixed manifests:**
- `metadata.resourceVersion`
- `metadata.uid`
- `metadata.selfLink`
- `metadata.creationTimestamp`
- `metadata.generation`
- `metadata.managedFields`
- `status` (entire section)

**Example AI workflow for fixing a deployment with wrong image:**
```
1. kubectl get deployment myapp -n prod -o yaml > $SESSION_DIR/backup-deployment-myapp.yaml
2. AI reads backup, identifies image: "myapp:broken"
3. AI creates fixed manifest at $SESSION_DIR/fixed-deployment-myapp.yaml with:
   - Removed cluster fields
   - Changed image to "myapp:v1.2.3"
4. scripts/apply_with_tracking.sh "$SESSION_DIR/fixed-deployment-myapp.yaml"
```

**NEVER use imperative commands like:**
- `kubectl set image`
- `kubectl scale`
- `kubectl edit`
- `kubectl patch`
- `kubectl create` (without saving YAML first)

**ALWAYS:**
1. Export current resource as YAML
2. Modify the YAML file
3. Apply via `kubectl apply -f`
4. Track changes in session change file

### 5. show-k8s-changes Command

When user requests `show-k8s-changes`:
1. Display all accumulated changes from session file
2. Validate YAML syntax
3. Add metadata comments for each change
4. Group by namespace and resource type

**Execute:**
- Bash: `scripts/show_changes.sh`
- PowerShell: `.\scripts\ps1\Show-K8sChanges.ps1`

## Diagnostic Patterns

### Pod Issues

**Bash:**
```bash
# Pod not starting
scripts/diagnose_pod.sh <namespace> <pod-name>
```

**PowerShell:**
```powershell
# Pod not starting
.\scripts\ps1\Diagnose-K8sPod.ps1 -Namespace <namespace> -PodName <pod-name>
```

**Common fixes tracked as YAML:**
- Resource limits adjustment
- Image pull secrets
- Security context modifications
- Volume mount corrections

### Service Discovery

**Bash:**
```bash
# Service connectivity issues
scripts/test_service.sh <namespace> <service-name>
```

**PowerShell:**
```powershell
# Service connectivity issues
.\scripts\ps1\Test-K8sService.ps1 -Namespace <namespace> -ServiceName <service-name>
```

**DNS troubleshooting (any shell):**
```bash
kubectl run -it --rm debug --image=busybox --restart=Never -- nslookup <service>
```

### Storage Issues

**Bash:**
```bash
# PVC debugging
scripts/debug_storage.sh <namespace>
```

**PowerShell:**
```powershell
# PVC debugging
.\scripts\ps1\Debug-K8sStorage.ps1 -Namespace <namespace>
```

**Additional checks (any shell):**
```bash
# Check storage classes
kubectl get storageclass
kubectl describe pvc -n <namespace>
```

## Tekton-Specific Operations

Pipeline debugging workflow:
```bash
# List pipeline runs
tkn pipelinerun list -n <namespace>

# Describe failed run
tkn pipelinerun describe <name> -n <namespace>

# Check TaskRun logs
tkn taskrun logs <taskrun-name> -n <namespace>
```

See references/tekton-troubleshooting.md for detailed patterns.

## Crossplane Management

XR troubleshooting:
```bash
# Check XR status
kubectl get xr -A

# Describe composition
kubectl describe composition <name>

# Check provider configs
kubectl get providerconfig -A
```

See references/crossplane-troubleshooting.md for XR debugging.

## ArgoCD Operations

Application sync issues:
```bash
# Check app status
argocd app get <app-name>

# Force sync with prune
argocd app sync <app-name> --prune --force

# Check sync hooks
kubectl get jobs -n <namespace> -l argocd.argoproj.io/hook
```

See references/argocd-troubleshooting.md for sync strategies.

## Session Finalization

**At session end (concise summary only)**:

1. **Display brief summary**:
   - Total changes made
   - Session temp directory location

   Example for local/dev:
   ```
   ✅ Issue resolved!

   Session files: C:\Users\...\AppData\Local\Temp\k8s-troubleshooter\20251208-161143\
   - Changes tracked: k8s-changes.yaml
   - Backups: backup-*.yaml
   ```

2. **For production environments only**:
   - Show GitOps integration instructions
   - Remind about repository commit requirements
   - Update Jira ticket with changes

3. **DO NOT show**:
   - Lengthy German warnings for local/dev
   - Jira integration steps for local/dev
   - Verbose repository instructions unless production

## PowerShell Compatibility

For Windows/PowerShell environments, all core scripts have PowerShell equivalents:

### Health Check
```powershell
# Cluster health check with detailed information
./scripts/ps1/Get-K8sHealth.ps1 -Namespace <namespace> -Detailed
```

### Change Tracking
```powershell
# Track a change (used internally by Apply-K8sWithTracking.ps1)
./scripts/ps1/Track-K8sChange.ps1 -ResourceType deployment `
    -ResourceName myapp -Namespace default `
    -Operation UPDATE -Manifest $yamlContent

# Display all tracked changes
./scripts/ps1/Show-K8sChanges.ps1

# Apply manifest with automatic tracking
./scripts/ps1/Apply-K8sWithTracking.ps1 -ManifestFile manifest.yaml
```

### Environment Setup
```powershell
# Set session variables for change tracking
$jiraTicket = "PROJECT-12345"
$sessionDir = "$env:TEMP\k8s-troubleshooter\$(Get-Date -Format 'yyyyMMdd-HHmmss')-$jiraTicket"
New-Item -ItemType Directory -Path $sessionDir -Force | Out-Null

$env:K8S_SESSION_DIR = $sessionDir
$env:K8S_CHANGE_FILE = "$sessionDir\k8s-changes-$jiraTicket.yaml"
$env:JIRA_TICKET = $jiraTicket

Write-Host "Session directory: $sessionDir"
```

### Installation
```powershell
# Run the PowerShell installer
./Install-K8sTroubleshooter.ps1
```

**Note**: PowerShell scripts use `$env:TEMP` instead of `/tmp` for Windows compatibility and `$env:K8S_CHANGE_FILE` instead of `$CHANGE_FILE`.

## Critical Rules

1. **Never apply write operations without user confirmation** (read operations need no confirmation)
2. **Always maintain declarative YAML record for changes**
3. **Group related changes in single manifests**
4. **Include resource versions for update operations**
5. **Add comments explaining each change**
6. **Test changes in dev/staging first if possible**
7. **CRITICAL: ALL session files MUST be created in temp directories ONLY**
   - Linux/Mac: Use `/tmp/k8s-troubleshooter/` directory
   - Windows: Use `$env:TEMP\k8s-troubleshooter\` directory
   - NEVER create k8s-changes-*.yaml, backup-*.yaml, or fixed-*.yaml files in the current working directory or git repository
   - Prevents accidental commits of session files
8. **Be concise and efficient**:
   - DO NOT display GitOps warnings for local/dev environments
   - DO NOT ask for Jira tickets for local/dev environments
   - DO NOT show verbose output unless debugging requires it
   - Only show critical information and actionable items
   - Silently perform all read-only operations
9. **Session file finalization**:
   - At session end, inform user where their session files are located in temp directory
   - Only display GitOps integration instructions if in production or user requests it

## Error Recovery

If changes cause issues:

**Bash/Linux:**
```bash
# Rollback using backup FROM SESSION TEMP DIRECTORY
kubectl apply -f "$SESSION_DIR/backup-<resource>-<name>.yaml"

# Or use kubectl rollout
kubectl rollout undo deployment/<name> -n <namespace>
```

**PowerShell/Windows:**
```powershell
# Rollback using backup FROM SESSION TEMP DIRECTORY
kubectl apply -f "$env:K8S_SESSION_DIR\backup-<resource>-<name>.yaml"

# Or use kubectl rollout
kubectl rollout undo deployment/<name> -n <namespace>
```

## Integration Points

- **Jira API**: See scripts/jira_integration.py
- **Bitbucket Webhook**: Trigger on manifest commits
- **Slack Notifications**: Optional alerting via scripts/notify_slack.sh
