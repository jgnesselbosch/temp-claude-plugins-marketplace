# Show-K8sChanges.ps1 - Display all Kubernetes changes from current session

param(
    [Parameter(Mandatory=$false)]
    [string]$ChangeFile
)

# Find the change file
if (-not $ChangeFile) {
    # Use environment variable if set
    $ChangeFile = $env:K8S_CHANGE_FILE

    # Otherwise, find the most recent file
    if (-not $ChangeFile) {
        $changeFiles = Get-ChildItem -Path $env:TEMP -Filter "k8s-changes-*.yaml" -ErrorAction SilentlyContinue |
            Sort-Object LastWriteTime -Descending

        if ($changeFiles) {
            $ChangeFile = $changeFiles[0].FullName
        }
    }
}

if (-not $ChangeFile -or -not (Test-Path $ChangeFile)) {
    Write-Host "No changes tracked in this session." -ForegroundColor Yellow
    Write-Host "Start tracking changes by using Apply-K8sWithTracking.ps1"
    exit 0
}

Write-Host "=========================================" -ForegroundColor Green
Write-Host "  Kubernetes Session Changes Summary" -ForegroundColor Green
Write-Host "=========================================" -ForegroundColor Green
Write-Host ""
Write-Host "Session file: $ChangeFile" -ForegroundColor Cyan

$jiraTicket = $env:JIRA_TICKET
if (-not $jiraTicket) {
    $jiraTicket = "Not set - Please set `$env:JIRA_TICKET"
}
Write-Host "Jira Ticket: $jiraTicket" -ForegroundColor Cyan
Write-Host ""

# Read the file content
$content = Get-Content -Path $ChangeFile -Raw

# Count changes (each change starts with "---")
$totalChanges = ([regex]::Matches($content, "^---$", [System.Text.RegularExpressions.RegexOptions]::Multiline)).Count
Write-Host "Total changes tracked: $totalChanges" -ForegroundColor Yellow

# Extract unique namespaces
$namespaceMatches = [regex]::Matches($content, "# Namespace:\s*(\S+)")
$namespaces = $namespaceMatches | ForEach-Object { $_.Groups[1].Value } | Select-Object -Unique
$namespaceList = $namespaces -join ", "
Write-Host "Affected namespaces: $namespaceList" -ForegroundColor Yellow

# Extract resource types
$resourceMatches = [regex]::Matches($content, "# Resource:\s*([^/]+)/")
$resources = $resourceMatches | ForEach-Object { $_.Groups[1].Value } | Select-Object -Unique
$resourceList = $resources -join ", "
Write-Host "Modified resource types: $resourceList" -ForegroundColor Yellow

Write-Host ""
Write-Host "=========================================" -ForegroundColor Green
Write-Host "  Declarative YAML Manifests" -ForegroundColor Green
Write-Host "=========================================" -ForegroundColor Green
Write-Host ""

# Display the complete YAML
Write-Host $content

Write-Host ""
Write-Host "=========================================" -ForegroundColor Green
Write-Host "  Next Steps" -ForegroundColor Green
Write-Host "=========================================" -ForegroundColor Green
Write-Host ""
Write-Host "1. Review the changes above"
Write-Host "2. Save manifests to Git repository:"
Write-Host "   git add `"$ChangeFile`"" -ForegroundColor Gray
Write-Host "   git commit -m `"K8s changes for $jiraTicket`"" -ForegroundColor Gray
Write-Host "   git push origin feature/$jiraTicket" -ForegroundColor Gray
Write-Host ""
Write-Host "3. To apply all changes at once:"
Write-Host "   kubectl apply -f `"$ChangeFile`"" -ForegroundColor Gray
Write-Host ""
Write-Host "4. To rollback changes, use backup files in $env:TEMP\backup-*"
Write-Host ""
Write-Host "WICHTIG: Diese Anderungen mussen ins Git-Repository (Bitbucket) eingepflegt werden!" -ForegroundColor Red
