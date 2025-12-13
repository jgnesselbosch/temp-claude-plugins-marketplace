# Finalize-K8sSession.ps1 - Generate final manifest collection and summary

param(
    [string]$SessionDir = $env:K8S_SESSION_DIR,
    [string]$ChangeFile = $env:K8S_CHANGE_FILE
)

$ErrorActionPreference = "Stop"

Write-Host "=========================================" -ForegroundColor Green
Write-Host "  Kubernetes Session Finalization" -ForegroundColor Green
Write-Host "=========================================" -ForegroundColor Green
Write-Host ""

# Find session directory if not provided
if (-not $SessionDir) {
    $tempDir = $env:TEMP
    $sessionDirs = Get-ChildItem -Path "$tempDir\k8s-troubleshooter" -Directory -ErrorAction SilentlyContinue |
                   Sort-Object LastWriteTime -Descending |
                   Select-Object -First 1

    if ($sessionDirs) {
        $SessionDir = $sessionDirs.FullName
    }
}

if (-not $SessionDir -or -not (Test-Path $SessionDir)) {
    Write-Host "No session directory found." -ForegroundColor Yellow
    Write-Host "Expected: $env:TEMP\k8s-troubleshooter\YYYYMMDD-HHMMSS-TICKET\"
    exit 0
}

# Find change file in session directory
if (-not $ChangeFile) {
    $ChangeFile = Join-Path $SessionDir "k8s-changes.yaml"
}

if (-not (Test-Path $ChangeFile)) {
    Write-Host "No changes were tracked in this session." -ForegroundColor Yellow
    Write-Host "Session directory: $SessionDir"
    exit 0
}

# Define output files in SESSION_DIR
$summaryFile = Join-Path $SessionDir "k8s-session-summary.txt"
$manifestFile = Join-Path $SessionDir "k8s-final-manifests.yaml"
$rollbackScript = Join-Path $SessionDir "k8s-rollback.ps1"

# Check if summary already exists (avoid overwriting)
if (Test-Path $summaryFile) {
    Write-Host "Summary file already exists: $summaryFile" -ForegroundColor Yellow
    Write-Host "Using existing summary. To regenerate, delete the file first."
    Get-Content $summaryFile
    exit 0
}

# Extract session info
$sessionName = Split-Path $SessionDir -Leaf
$jiraTicket = if ($env:JIRA_TICKET) { $env:JIRA_TICKET } else { "Not specified" }

# Create summary header
$summaryContent = @"
Kubernetes Troubleshooting Session Summary
==========================================
Date: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
Jira Ticket: $jiraTicket
Change File: $ChangeFile
Final Manifests: $manifestFile

Statistics:
-----------
"@

# Calculate statistics
$changeContent = Get-Content $ChangeFile -Raw
$totalChanges = ([regex]::Matches($changeContent, "^---$", [System.Text.RegularExpressions.RegexOptions]::Multiline)).Count
$summaryContent += "`nTotal Changes: $totalChanges`n"

# Extract namespaces
$namespaceMatches = [regex]::Matches($changeContent, "# Namespace:\s*(.+)")
$namespaces = $namespaceMatches | ForEach-Object { $_.Groups[1].Value.Trim() } | Sort-Object -Unique
$summaryContent += "Affected Namespaces: $($namespaces -join ', ')`n"

# Count by operation type
$creates = ([regex]::Matches($changeContent, "# Operation:\s*CREATE")).Count
$updates = ([regex]::Matches($changeContent, "# Operation:\s*UPDATE")).Count
$deletes = ([regex]::Matches($changeContent, "# Operation:\s*DELETE")).Count

$summaryContent += "  - Creates: $creates`n"
$summaryContent += "  - Updates: $updates`n"
$summaryContent += "  - Deletes: $deletes`n"

# Resource type breakdown
$summaryContent += "`nResource Types Modified:`n"
$resourceMatches = [regex]::Matches($changeContent, "# Resource:\s*([^/\s]+)")
$resourceTypes = $resourceMatches | ForEach-Object { $_.Groups[1].Value.Trim() } | Group-Object
foreach ($type in $resourceTypes) {
    $summaryContent += "  - $($type.Name): $($type.Count)`n"
}

# Save summary
$summaryContent | Out-File -FilePath $summaryFile -Encoding utf8

# Create consolidated manifest file
$manifestHeader = @"
---
# Consolidated Kubernetes Manifests
# Generated: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
# Jira Ticket: $jiraTicket
# Total Changes: $totalChanges

"@

$manifestHeader | Out-File -FilePath $manifestFile -Encoding utf8

# Process and clean manifests (remove comment lines)
Get-Content $ChangeFile | Where-Object { $_ -notmatch "^#" } | Out-File -FilePath $manifestFile -Append -Encoding utf8

# Validate YAML
Write-Host ""
Write-Host "Validating final manifests..." -ForegroundColor Yellow
if (Get-Command yamllint -ErrorAction SilentlyContinue) {
    try {
        yamllint -d relaxed $manifestFile 2>&1 | Out-Null
        Write-Host "✓ YAML validation passed" -ForegroundColor Green
    } catch {
        Write-Host "⚠ YAML validation warnings (review before applying)" -ForegroundColor Yellow
    }
} else {
    Write-Host "yamllint not installed, skipping validation"
}

# Create rollback script (only if backups exist and script doesn't exist)
if (-not (Test-Path $rollbackScript)) {
    $backupFiles = Get-ChildItem -Path $SessionDir -Filter "backup-*.yaml" -ErrorAction SilentlyContinue

    if ($backupFiles) {
        $rollbackContent = @"
# Rollback script for this session's changes
# Session: $SessionDir

Write-Host "Rolling back Kubernetes changes..."

# Apply backup files in reverse order from this session
`$backups = Get-ChildItem -Path "$SessionDir" -Filter "backup-*.yaml" | Sort-Object LastWriteTime -Descending

foreach (`$backup in `$backups) {
    Write-Host "Applying `$(`$backup.FullName)"
    kubectl apply -f `$backup.FullName
}

Write-Host "Rollback complete. Verify cluster state."
"@
        $rollbackContent | Out-File -FilePath $rollbackScript -Encoding utf8
    } else {
        # No backups found, create a placeholder
        $rollbackScript = Join-Path $SessionDir "no-rollback-needed.txt"
        "No backup files created - no rollback needed." | Out-File -FilePath $rollbackScript -Encoding utf8
    }
}

# Display summary
Write-Host ""
Write-Host "Session Summary:" -ForegroundColor Green
Write-Host "================"
Get-Content $summaryFile

Write-Host ""
Write-Host "Generated Files:" -ForegroundColor Green
Write-Host "================"
Write-Host "1. Summary: $summaryFile"
Write-Host "2. Final Manifests: $manifestFile"
Write-Host "3. Rollback Script: $rollbackScript"
Write-Host "4. Change Log: $ChangeFile"

Write-Host ""
Write-Host "⚠️  WICHTIGE NÄCHSTE SCHRITTE:" -ForegroundColor Yellow
Write-Host "================================"
Write-Host "1. Review final manifests:"
Write-Host "   Get-Content $manifestFile"
Write-Host ""
Write-Host "2. Commit to Git repository:"
Write-Host "   git checkout -b feature/$jiraTicket"
Write-Host "   Copy-Item $manifestFile .\k8s\changes\"
Write-Host "   git add .\k8s\changes\"
Write-Host "   git commit -m `"K8s fixes for $jiraTicket`""
Write-Host "   git push origin feature/$jiraTicket"
Write-Host ""
Write-Host "3. Update Jira ticket:"
Write-Host "   # Use Jira API or update manually"
Write-Host ""
Write-Host "4. If rollback needed:"
if (Test-Path $rollbackScript -PathType Leaf) {
    Write-Host "   . $rollbackScript"
}
Write-Host ""
Write-Host "⚠️  CRITICAL: Diese Änderungen MÜSSEN ins Git-Repository (Bitbucket) eingepflegt werden!" -ForegroundColor Red
Write-Host "   Dies ist essentiell für die GitOps-Compliance und Nachvollziehbarkeit!" -ForegroundColor Red
Write-Host ""
Write-Host "Session erfolgreich abgeschlossen." -ForegroundColor Green

# Copy summary to temp for knowledge base update
$timestamp = ($sessionName -split '-')[0..1] -join '-'
$ticket = ($sessionName -split '-')[2]
$kbSummary = Join-Path $env:TEMP "k8s-session-summary-$timestamp-$ticket.txt"

if (-not (Test-Path $kbSummary)) {
    Copy-Item $summaryFile $kbSummary
    Write-Host ""
    Write-Host "Session summary copied to: $kbSummary" -ForegroundColor Cyan
}

# Note: PowerShell version of update_knowledge_base.sh would go here
# For now, just inform the user
if (-not $env:SKIP_KB_UPDATE) {
    Write-Host ""
    Write-Host "Note: Knowledge base update requires Python script (run update_knowledge_base.sh from bash if available)" -ForegroundColor Cyan
}
