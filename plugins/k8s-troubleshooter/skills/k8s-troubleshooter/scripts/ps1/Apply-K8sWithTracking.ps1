# Apply-K8sWithTracking.ps1 - Apply Kubernetes manifests with automatic tracking

param(
    [Parameter(Mandatory=$true)]
    [string]$ManifestFile
)

# Check if manifest file exists
if (-not (Test-Path $ManifestFile)) {
    Write-Host "Error: Manifest file not found: $ManifestFile" -ForegroundColor Red
    exit 1
}

# Check if kubectl is available
if (-not (Get-Command kubectl -ErrorAction SilentlyContinue)) {
    Write-Host "Error: kubectl not found in PATH" -ForegroundColor Red
    exit 1
}

# Initialize change file if not set
if (-not $env:K8S_CHANGE_FILE) {
    $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $env:K8S_CHANGE_FILE = Join-Path $env:TEMP "k8s-changes-$timestamp.yaml"
}

Write-Host "Processing manifest: $ManifestFile" -ForegroundColor Cyan
Write-Host ""

try {
    # Extract resource information using dry-run
    $dryRunOutput = kubectl apply -f $ManifestFile --dry-run=client -o name 2>&1

    if ($LASTEXITCODE -ne 0) {
        Write-Host "Error: Failed to parse manifest file" -ForegroundColor Red
        Write-Host $dryRunOutput
        exit 1
    }

    # Parse resource type and name
    $resourceParts = $dryRunOutput -split '/'
    $resourceType = $resourceParts[0]
    $resourceName = $resourceParts[1]

    # Extract namespace from manifest
    $manifestContent = Get-Content -Path $ManifestFile -Raw
    $namespaceMatch = [regex]::Match($manifestContent, "^\s*namespace:\s*(\S+)", [System.Text.RegularExpressions.RegexOptions]::Multiline)

    if ($namespaceMatch.Success) {
        $namespace = $namespaceMatch.Groups[1].Value
    } else {
        $namespace = "default"
    }

    Write-Host "Resource Type: $resourceType" -ForegroundColor Yellow
    Write-Host "Resource Name: $resourceName" -ForegroundColor Yellow
    Write-Host "Namespace: $namespace" -ForegroundColor Yellow
    Write-Host ""

    # Check if resource exists (for update vs create detection)
    $resourceExists = $false
    try {
        $checkResult = kubectl get $resourceType $resourceName -n $namespace 2>$null
        if ($LASTEXITCODE -eq 0) {
            $resourceExists = $true
        }
    } catch {
        $resourceExists = $false
    }

    if ($resourceExists) {
        $operation = "UPDATE"
        Write-Host "Resource exists - performing UPDATE" -ForegroundColor Yellow

        # Backup existing resource
        Write-Host "Backing up existing resource..." -ForegroundColor Cyan
        $backupTimestamp = Get-Date -Format "yyyyMMdd-HHmmss"
        $backupFile = Join-Path $env:TEMP "backup-$resourceType-$resourceName-$backupTimestamp.yaml"

        kubectl get $resourceType $resourceName -n $namespace -o yaml | Out-File -FilePath $backupFile -Encoding UTF8
        Write-Host "Backup saved to: $backupFile" -ForegroundColor Green
    } else {
        $operation = "CREATE"
        Write-Host "Resource does not exist - performing CREATE" -ForegroundColor Yellow
    }

    Write-Host ""
    Write-Host "Applying manifest..." -ForegroundColor Cyan

    # Apply the manifest
    $applyResult = kubectl apply -f $ManifestFile 2>&1

    if ($LASTEXITCODE -eq 0) {
        Write-Host "Successfully applied $resourceType/$resourceName" -ForegroundColor Green
        Write-Host $applyResult
        Write-Host ""

        # Track the change
        Write-Host "Tracking change..." -ForegroundColor Cyan
        $scriptPath = Join-Path $PSScriptRoot "Track-K8sChange.ps1"

        & $scriptPath -ResourceType $resourceType `
                      -ResourceName $resourceName `
                      -Namespace $namespace `
                      -Operation $operation `
                      -Manifest $manifestContent

        Write-Host ""

        # Verify the resource
        Write-Host "Verifying resource state..." -ForegroundColor Cyan
        kubectl get $resourceType $resourceName -n $namespace

        Write-Host ""
        Write-Host "Change tracked in: $env:K8S_CHANGE_FILE" -ForegroundColor Green
        Write-Host "Use 'Show-K8sChanges.ps1' to view all session changes" -ForegroundColor Green

    } else {
        Write-Host "Failed to apply manifest" -ForegroundColor Red
        Write-Host $applyResult
        exit 1
    }

} catch {
    Write-Host "Error occurred: $_" -ForegroundColor Red
    exit 1
}
