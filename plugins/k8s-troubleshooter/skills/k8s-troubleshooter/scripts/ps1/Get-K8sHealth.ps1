# Get-K8sHealth.ps1 - PowerShell script for Kubernetes cluster health check

param(
    [Parameter(Mandatory=$false)]
    [string]$Namespace = "default",
    
    [Parameter(Mandatory=$false)]
    [switch]$Detailed,
    
    [Parameter(Mandatory=$false)]
    [string]$OutputFile
)

# Colors for output
function Write-ColorOutput($ForegroundColor) {
    $fc = $host.UI.RawUI.ForegroundColor
    $host.UI.RawUI.ForegroundColor = $ForegroundColor
    $input | Write-Output
    $host.UI.RawUI.ForegroundColor = $fc
}

Write-Host "==========================================" -ForegroundColor Green
Write-Host "  Kubernetes Cluster Health Check" -ForegroundColor Green
Write-Host "==========================================" -ForegroundColor Green
Write-Host ""

# Check kubectl availability
if (-not (Get-Command kubectl -ErrorAction SilentlyContinue)) {
    Write-Host "Error: kubectl not found in PATH" -ForegroundColor Red
    exit 1
}

# Get cluster info
Write-Host "📊 Cluster Information:" -ForegroundColor Yellow
kubectl cluster-info | Select-String "Kubernetes" | Write-ColorOutput Green

$context = kubectl config current-context
Write-Host "Current Context: $context" -ForegroundColor Cyan
Write-Host ""

# Node status
Write-Host "🖥️ Node Status:" -ForegroundColor Yellow
$nodes = kubectl get nodes -o json | ConvertFrom-Json
$nodeCount = $nodes.items.Count
$readyNodes = ($nodes.items | Where-Object { $_.status.conditions | Where-Object { $_.type -eq "Ready" -and $_.status -eq "True" } }).Count

Write-Host "Total Nodes: $nodeCount"
Write-Host "Ready Nodes: $readyNodes" -ForegroundColor $(if ($readyNodes -eq $nodeCount) { "Green" } else { "Yellow" })

if ($Detailed) {
    kubectl get nodes -o wide
}
Write-Host ""

# Namespace resources
Write-Host "📦 Resources in namespace '$Namespace':" -ForegroundColor Yellow
$resources = @{
    "Deployments" = "deployments"
    "Pods" = "pods"
    "Services" = "services"
    "ConfigMaps" = "configmaps"
    "Secrets" = "secrets"
}

$summary = @{}
foreach ($item in $resources.GetEnumerator()) {
    $count = (kubectl get $item.Value -n $Namespace -o json | ConvertFrom-Json).items.Count
    $summary[$item.Key] = $count
    Write-Host "$($item.Key): $count"
}
Write-Host ""

# Pod health
Write-Host "🏥 Pod Health in '$Namespace':" -ForegroundColor Yellow
$pods = kubectl get pods -n $Namespace -o json | ConvertFrom-Json
$runningPods = ($pods.items | Where-Object { $_.status.phase -eq "Running" }).Count
$pendingPods = ($pods.items | Where-Object { $_.status.phase -eq "Pending" }).Count
$failedPods = ($pods.items | Where-Object { $_.status.phase -eq "Failed" }).Count

Write-Host "Running: $runningPods" -ForegroundColor Green
if ($pendingPods -gt 0) {
    Write-Host "Pending: $pendingPods" -ForegroundColor Yellow
}
if ($failedPods -gt 0) {
    Write-Host "Failed: $failedPods" -ForegroundColor Red
}

# Problem pods
$problemPods = $pods.items | Where-Object { 
    $_.status.phase -ne "Running" -or 
    ($_.status.containerStatuses | Where-Object { $_.ready -eq $false }).Count -gt 0
}

if ($problemPods.Count -gt 0) {
    Write-Host ""
    Write-Host "⚠️ Problem Pods:" -ForegroundColor Red
    foreach ($pod in $problemPods) {
        Write-Host "  - $($pod.metadata.name): $($pod.status.phase)" -ForegroundColor Yellow
        if ($Detailed) {
            $events = kubectl get events -n $Namespace --field-selector "involvedObject.name=$($pod.metadata.name)" -o json | ConvertFrom-Json
            $recentEvents = $events.items | Select-Object -Last 3
            foreach ($event in $recentEvents) {
                Write-Host "    Event: $($event.reason) - $($event.message)" -ForegroundColor Gray
            }
        }
    }
}
Write-Host ""

# Recent events
Write-Host "📅 Recent Warning Events:" -ForegroundColor Yellow
$warnings = kubectl get events -n $Namespace --field-selector "type=Warning" -o json | ConvertFrom-Json
$recentWarnings = $warnings.items | Sort-Object -Property lastTimestamp -Descending | Select-Object -First 5

if ($recentWarnings.Count -eq 0) {
    Write-Host "No warning events found ✓" -ForegroundColor Green
} else {
    foreach ($warning in $recentWarnings) {
        Write-Host "  [$($warning.lastTimestamp)] $($warning.reason): $($warning.message)" -ForegroundColor Yellow
    }
}
Write-Host ""

# Tekton resources (if available)
if (kubectl get crds | Select-String "tekton.dev") {
    Write-Host "🔧 Tekton Resources:" -ForegroundColor Yellow
    $pipelineruns = (kubectl get pipelineruns -n $Namespace -o json 2>$null | ConvertFrom-Json).items.Count
    $taskruns = (kubectl get taskruns -n $Namespace -o json 2>$null | ConvertFrom-Json).items.Count
    Write-Host "PipelineRuns: $pipelineruns"
    Write-Host "TaskRuns: $taskruns"
    Write-Host ""
}

# ArgoCD applications (if available)
if (kubectl get crds | Select-String "argoproj.io") {
    Write-Host "🔄 ArgoCD Applications:" -ForegroundColor Yellow
    $apps = kubectl get applications -n argocd -o json 2>$null | ConvertFrom-Json
    if ($apps) {
        $syncedApps = ($apps.items | Where-Object { $_.status.sync.status -eq "Synced" }).Count
        Write-Host "Total Applications: $($apps.items.Count)"
        Write-Host "Synced: $syncedApps" -ForegroundColor Green
    }
    Write-Host ""
}

# Generate report if requested
if ($OutputFile) {
    $report = @{
        Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        Context = $context
        Namespace = $Namespace
        NodeStatus = @{
            Total = $nodeCount
            Ready = $readyNodes
        }
        Resources = $summary
        PodStatus = @{
            Running = $runningPods
            Pending = $pendingPods
            Failed = $failedPods
        }
        ProblemPods = $problemPods | ForEach-Object { 
            @{
                Name = $_.metadata.name
                Phase = $_.status.phase
            }
        }
    }
    
    $report | ConvertTo-Json -Depth 10 | Out-File $OutputFile
    Write-Host "Report saved to: $OutputFile" -ForegroundColor Green
}

Write-Host "==========================================" -ForegroundColor Green
Write-Host "  Health check complete" -ForegroundColor Green
Write-Host "==========================================" -ForegroundColor Green
