# Track-K8sChange.ps1 - Track Kubernetes changes in declarative YAML format

param(
    [Parameter(Mandatory=$true)]
    [string]$ResourceType,

    [Parameter(Mandatory=$true)]
    [string]$ResourceName,

    [Parameter(Mandatory=$true)]
    [string]$Namespace,

    [Parameter(Mandatory=$true)]
    [ValidateSet("CREATE", "UPDATE", "DELETE", "PATCH")]
    [string]$Operation,

    [Parameter(Mandatory=$true)]
    [string]$Manifest
)

# Use environment variable or create new file
$changeFile = $env:K8S_CHANGE_FILE
if (-not $changeFile) {
    $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $changeFile = Join-Path $env:TEMP "k8s-changes-$timestamp.yaml"
    $env:K8S_CHANGE_FILE = $changeFile
}

$timestamp = Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ" -AsUTC
$jiraTicket = $env:JIRA_TICKET
if (-not $jiraTicket) {
    $jiraTicket = "NOT_SET"
}

# Prepare metadata
$metadata = @"
---
# Change tracked at: $timestamp
# Operation: $Operation
# Resource: $ResourceType/$ResourceName
# Namespace: $Namespace
# Jira Ticket: $jiraTicket

"@

# Append to change file
Add-Content -Path $changeFile -Value $metadata
Add-Content -Path $changeFile -Value $Manifest

Write-Host "Change tracked in: $changeFile" -ForegroundColor Green

# Return the change file path for use in scripts
return $changeFile
