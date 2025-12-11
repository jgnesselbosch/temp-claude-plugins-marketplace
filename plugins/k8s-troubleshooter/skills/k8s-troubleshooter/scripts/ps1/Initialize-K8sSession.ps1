# Initialize-K8sSession.ps1 - Initialize K8s troubleshooting session with temp directory and change tracking

[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [string]$JiraTicket = "NO-TICKET"
)

# Create dedicated temp directory for session
$timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$sessionDir = "$env:TEMP\k8s-troubleshooter\$timestamp-$JiraTicket"
New-Item -ItemType Directory -Path $sessionDir -Force | Out-Null

# Initialize change tracking file
$changeFile = "$sessionDir\k8s-changes-$JiraTicket.yaml"
$currentContext = kubectl config current-context 2>$null
$currentDate = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

$changeHeader = @"
Kubernetes Changes - Session $currentDate
Ticket: $JiraTicket
Cluster: $currentContext
Date: $currentDate
"@

Set-Content -Path $changeFile -Value $changeHeader -Encoding UTF8

# Set environment variables for session
$env:K8S_SESSION_DIR = $sessionDir
$env:K8S_CHANGE_FILE = $changeFile
$env:JIRA_TICKET = $JiraTicket

Write-Host "✅ Session directory created: $sessionDir" -ForegroundColor Green
Write-Host "✅ Change tracking file: $changeFile" -ForegroundColor Green
Write-Host ""
Write-Host "Environment variables set:"
Write-Host "  `$env:K8S_SESSION_DIR = $sessionDir"
Write-Host "  `$env:K8S_CHANGE_FILE = $changeFile"
Write-Host "  `$env:JIRA_TICKET = $JiraTicket"
Write-Host ""
Write-Host "Note: These variables are set in your current session."
Write-Host "Usage: .\scripts\ps1\Initialize-K8sSession.ps1 [TICKET-ID]"
