# Test-K8sService.ps1 - Test Kubernetes service connectivity and configuration

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true, Position=0)]
    [string]$Namespace,

    [Parameter(Mandatory=$true, Position=1)]
    [string]$ServiceName
)

Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "  Service Testing: $ServiceName" -ForegroundColor Cyan
Write-Host "  Namespace: $Namespace" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host ""

# Check if service exists
$serviceExists = kubectl get service $ServiceName -n $Namespace 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Service not found: $ServiceName in namespace $Namespace" -ForegroundColor Red
    Write-Host ""
    Write-Host "Available services in namespace:"
    kubectl get services -n $Namespace
    exit 1
}

# Service details
Write-Host "📋 Service Information:" -ForegroundColor Yellow
kubectl get service $ServiceName -n $Namespace -o wide
Write-Host ""

# Service description
Write-Host "📝 Service Details:" -ForegroundColor Yellow
kubectl describe service $ServiceName -n $Namespace
Write-Host ""

# Check endpoints
Write-Host "🔗 Service Endpoints:" -ForegroundColor Yellow
$endpoints = kubectl get endpoints $ServiceName -n $Namespace -o jsonpath='{.subsets[*].addresses[*].ip}' 2>$null

if ([string]::IsNullOrEmpty($endpoints)) {
    Write-Host "⚠️  WARNING: No endpoints found! Service has no backing pods." -ForegroundColor Red
    Write-Host ""
    Write-Host "Checking for matching pods..."
    
    $serviceJson = kubectl get service $ServiceName -n $Namespace -o json | ConvertFrom-Json
    if ($serviceJson.spec.selector) {
        $selectorParts = @()
        foreach ($key in $serviceJson.spec.selector.PSObject.Properties.Name) {
            $selectorParts += "$key=$($serviceJson.spec.selector.$key)"
        }
        $selector = $selectorParts -join ","
        Write-Host "Service selector: $selector"
        kubectl get pods -n $Namespace -l $selector
    }
} else {
    kubectl get endpoints $ServiceName -n $Namespace
    Write-Host ""
    Write-Host "✅ Endpoints found: $endpoints" -ForegroundColor Green
}
Write-Host ""

# Service type specific checks
$serviceType = kubectl get service $ServiceName -n $Namespace -o jsonpath='{.spec.type}'
Write-Host "📦 Service Type: $serviceType" -ForegroundColor Yellow

switch ($serviceType) {
    "LoadBalancer" {
        Write-Host ""
        Write-Host "🌐 LoadBalancer Configuration:"
        $externalIp = kubectl get service $ServiceName -n $Namespace -o jsonpath='{.status.loadBalancer.ingress[0].ip}'
        $externalHostname = kubectl get service $ServiceName -n $Namespace -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
        
        if (-not [string]::IsNullOrEmpty($externalIp)) {
            Write-Host "External IP: $externalIp"
        } elseif (-not [string]::IsNullOrEmpty($externalHostname)) {
            Write-Host "External Hostname: $externalHostname"
        } else {
            Write-Host "⚠️  LoadBalancer external address is pending..." -ForegroundColor Yellow
        }
    }
    "NodePort" {
        Write-Host ""
        Write-Host "🔌 NodePort Configuration:"
        $nodePorts = kubectl get service $ServiceName -n $Namespace -o jsonpath='{.spec.ports[*].nodePort}'
        Write-Host "NodePorts: $nodePorts"
    }
    "ClusterIP" {
        $clusterIp = kubectl get service $ServiceName -n $Namespace -o jsonpath='{.spec.clusterIP}'
        Write-Host "Cluster IP: $clusterIp"
    }
}
Write-Host ""

# DNS test
Write-Host "🔍 DNS Resolution Test:" -ForegroundColor Yellow
Write-Host "Testing DNS resolution from within cluster..."

# Create a test pod for DNS lookup
$testPod = "dns-test-$(Get-Date -Format 'yyyyMMddHHmmss')"
kubectl run $testPod --image=busybox --rm -i --restart=Never --namespace=$Namespace -- nslookup "$ServiceName.$Namespace.svc.cluster.local" 2>&1
Write-Host ""

# Port configuration
Write-Host "🔌 Port Configuration:" -ForegroundColor Yellow
$ports = kubectl get service $ServiceName -n $Namespace -o jsonpath='{.spec.ports[*].port}'
$targetPorts = kubectl get service $ServiceName -n $Namespace -o jsonpath='{.spec.ports[*].targetPort}'
$protocols = kubectl get service $ServiceName -n $Namespace -o jsonpath='{.spec.ports[*].protocol}'

Write-Host "Service Ports: $ports"
Write-Host "Target Ports: $targetPorts"
Write-Host "Protocols: $protocols"
Write-Host ""

# Check for common issues
Write-Host "⚠️  Common Issues Check:" -ForegroundColor Yellow

# Check selector matches pods
$serviceJson = kubectl get service $ServiceName -n $Namespace -o json | ConvertFrom-Json
$selector = $serviceJson.spec.selector

if (-not $selector -or $selector.PSObject.Properties.Count -eq 0) {
    Write-Host "❌ Service has no selector! Cannot route traffic to pods." -ForegroundColor Red
} else {
    $selectorParts = @()
    foreach ($key in $selector.PSObject.Properties.Name) {
        $selectorParts += "$key=$($selector.$key)"
    }
    $selectorLabel = $selectorParts -join ","
    
    $podCount = (kubectl get pods -n $Namespace -l $selectorLabel --no-headers 2>$null | Measure-Object).Count
    
    if ($podCount -eq 0) {
        Write-Host "❌ No pods match service selector: $selectorLabel" -ForegroundColor Red
        Write-Host "   Create pods with matching labels"
    } else {
        Write-Host "✅ Found $podCount pod(s) matching selector" -ForegroundColor Green
    }
}
Write-Host ""

# Recent events
Write-Host "📅 Recent Events:" -ForegroundColor Yellow
$events = kubectl get events -n $Namespace --field-selector involvedObject.name=$ServiceName --sort-by='.lastTimestamp' 2>$null
if ($events) {
    $events | Select-Object -Last 5
} else {
    Write-Host "No recent events"
}
Write-Host ""

Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "  Troubleshooting Suggestions" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan

if ([string]::IsNullOrEmpty($endpoints)) {
    Write-Host "1. Service has no endpoints:"
    Write-Host "   - Verify pods exist with matching labels"
    Write-Host "   - Check pod readiness probes"
    Write-Host "   - Ensure targetPort matches container port"
}

if ($serviceType -eq "LoadBalancer" -and [string]::IsNullOrEmpty($externalIp) -and [string]::IsNullOrEmpty($externalHostname)) {
    Write-Host "2. LoadBalancer external address pending:"
    Write-Host "   - Check cloud provider integration"
    Write-Host "   - Verify LoadBalancer service quota"
    Write-Host "   - Check cluster events: kubectl get events -A"
}

Write-Host ""
Write-Host "Additional debugging commands:"
Write-Host "- Test from another pod: kubectl run -it --rm debug --image=busybox --restart=Never -- wget -O- http://$ServiceName.$Namespace.svc.cluster.local"
Write-Host "- Check service logs: kubectl logs -l <selector> -n $Namespace"
Write-Host "- Port forward for testing: kubectl port-forward svc/$ServiceName -n $Namespace <local-port>:<service-port>"
