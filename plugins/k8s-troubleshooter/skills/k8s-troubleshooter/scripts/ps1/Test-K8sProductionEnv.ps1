# Test-K8sProductionEnv.ps1 - Check for production environment and require explicit confirmation

param(
    [Parameter(Mandatory=$false)]
    [switch]$SkipConfirmation
)

# Check kubectl availability
if (-not (Get-Command kubectl -ErrorAction SilentlyContinue)) {
    Write-Host "Error: kubectl not found in PATH" -ForegroundColor Red
    exit 1
}

# Get current context information
try {
    $currentContext = kubectl config current-context 2>$null
    if (-not $currentContext) { $currentContext = "unknown" }
} catch {
    $currentContext = "unknown"
}

try {
    $currentNamespace = kubectl config view --minify -o jsonpath='{..namespace}' 2>$null
    if (-not $currentNamespace) { $currentNamespace = "default" }
} catch {
    $currentNamespace = "default"
}

try {
    $clusterUrl = kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}' 2>$null
    if (-not $clusterUrl) { $clusterUrl = "" }
} catch {
    $clusterUrl = ""
}

# Production indicators
$prodIndicators = @(
    "prod",
    "production",
    "prd",
    "live",
    "master"
)

# Check if environment is production
$isProduction = $false
$detectionReason = ""

foreach ($indicator in $prodIndicators) {
    if ($currentContext.ToLower() -like "*$indicator*") {
        $isProduction = $true
        $detectionReason = "Context contains '$indicator'"
        break
    }
    if ($currentNamespace.ToLower() -like "*$indicator*") {
        $isProduction = $true
        $detectionReason = "Namespace contains '$indicator'"
        break
    }
    if ($clusterUrl.ToLower() -like "*$indicator*") {
        $isProduction = $true
        $detectionReason = "Cluster URL contains '$indicator'"
        break
    }
}

# Also check environment variables
if ($env:K8S_ENVIRONMENT -eq "production" -or $env:ENVIRONMENT -eq "production") {
    $isProduction = $true
    $detectionReason = "Environment variable indicates production"
}

# Display environment information
Write-Host ""
Write-Host "Current Environment Information:" -ForegroundColor Cyan
Write-Host "================================" -ForegroundColor Cyan
Write-Host "Context:   $currentContext"
Write-Host "Namespace: $currentNamespace"
Write-Host "Cluster:   $clusterUrl"
Write-Host ""

if ($isProduction) {
    # Production environment detected
    Write-Host "==============================================================" -ForegroundColor Red
    Write-Host "                                                              " -ForegroundColor Red
    Write-Host "  WARNING: PRODUKTIVUMGEBUNG ERKANNT! WARNING               " -ForegroundColor Red -BackgroundColor DarkRed
    Write-Host "                                                              " -ForegroundColor Red
    Write-Host "==============================================================" -ForegroundColor Red
    Write-Host ""
    Write-Host "Detection Reason: $detectionReason" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "WICHTIG:" -ForegroundColor Red
    Write-Host "========" -ForegroundColor Red
    Write-Host "Dieser Skill darf NORMALERWEISE NICHT fur direkte Anderungen"
    Write-Host "an Produktivsystemen verwendet werden!"
    Write-Host ""
    Write-Host "Produktivanderungen sollten ausschliesslich uber:" -ForegroundColor Yellow
    Write-Host "  * Git-basierte CI/CD Pipelines"
    Write-Host "  * ArgoCD Sync"
    Write-Host "  * Approved Change Requests (mit Review)"
    Write-Host "erfolgen."
    Write-Host ""
    Write-Host "Nur in Notfallen (z.B. kritische Incidents) durfen" -ForegroundColor Yellow
    Write-Host "direkte Produktivanderungen vorgenommen werden!" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Sie bestatigen mit dem Fortfahren:" -ForegroundColor Red
    Write-Host "  X Direkte Produktivanderungen verstossen gegen IAC-Prinzipien"
    Write-Host "  X Alle Anderungen mussen dokumentiert und nachtragich ins Git ubernommen werden"
    Write-Host "  X Sie tragen die volle Verantwortung fur Produktivanderungen"
    Write-Host "  X Ein Jira-Ticket mit Incident/Change-Nummer ist zwingend erforderlich"
    Write-Host ""
    Write-Host "Um fortzufahren, geben Sie ein:" -ForegroundColor White
    Write-Host "CONFIRM-PROD-CHANGES-<TICKET-ID>" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Beispiel: CONFIRM-PROD-CHANGES-INC-12345"
    Write-Host ""

    if (-not $SkipConfirmation) {
        $userInput = Read-Host "Eingabe (oder 'exit' zum Abbrechen)"

        if ($userInput -eq "exit") {
            Write-Host ""
            Write-Host "[OK] Abgebrochen. Keine Anderungen vorgenommen." -ForegroundColor Green
            exit 0
        }

        # Validate input format: CONFIRM-PROD-CHANGES-PROJECT-123
        if ($userInput -match "^CONFIRM-PROD-CHANGES-[A-Z]+-[0-9]+$") {
            # Extract ticket ID
            $ticketId = $userInput -replace "^CONFIRM-PROD-CHANGES-", ""
            $env:JIRA_TICKET = $ticketId
            $env:PRODUCTION_CONFIRMED = "true"
            $confirmationTime = Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ" -AsUTC
            $env:PRODUCTION_CONFIRMATION_TIME = $confirmationTime

            Write-Host ""
            Write-Host "WARNING: Produktivzugriff bestatigt fur Ticket: $ticketId" -ForegroundColor Yellow
            Write-Host "         Zeit: $confirmationTime" -ForegroundColor Yellow
            Write-Host ""
            Write-Host "WARNUNG: Alle Anderungen werden geloggt und mussen"
            Write-Host "nachtragich ins Git-Repository ubernommen werden!"
            Write-Host ""

            # Log confirmation
            $logDate = Get-Date -Format "yyyyMMdd"
            $logFile = Join-Path $env:TEMP "k8s-prod-access-$logDate.log"

            $logEntry = @"
PRODUCTION ACCESS CONFIRMED
Time: $confirmationTime
Ticket: $ticketId
User: $env:USERNAME
Context: $currentContext
Namespace: $currentNamespace
Cluster: $clusterUrl
---

"@
            Add-Content -Path $logFile -Value $logEntry

        } else {
            Write-Host ""
            Write-Host "[ERROR] Ungultige Eingabe. Abgebrochen." -ForegroundColor Red
            Write-Host "Die Eingabe muss dem Format CONFIRM-PROD-CHANGES-<TICKET-ID> entsprechen."
            exit 1
        }
    }
} else {
    # Non-production environment
    Write-Host "[OK] Nicht-Produktivumgebung erkannt" -ForegroundColor Green
    Write-Host ""
    Write-Host "Sie arbeiten in einer Entwicklungs-/Test-Umgebung."
    Write-Host "Anderungen konnen sicher durchgefuhrt werden."
    Write-Host ""

    # Still ask for Jira ticket
    $ticketInput = Read-Host "Jira Ticket ID (optional, Enter zum Uberspringen)"
    if ($ticketInput) {
        $env:JIRA_TICKET = $ticketInput
        Write-Host "Ticket gesetzt: $($env:JIRA_TICKET)" -ForegroundColor Green
    }
}

Write-Host ""
Write-Host "Fahre mit Kubernetes-Troubleshooting fort..." -ForegroundColor Cyan
Write-Host "=============================================" -ForegroundColor Cyan
Write-Host ""

# Export environment type for other scripts
if ($isProduction) {
    $env:K8S_ENVIRONMENT_TYPE = "production"
} else {
    $env:K8S_ENVIRONMENT_TYPE = "development"
}

# Return status for calling scripts
return @{
    IsProduction = $isProduction
    Context = $currentContext
    Namespace = $currentNamespace
    Cluster = $clusterUrl
    DetectionReason = $detectionReason
    JiraTicket = $env:JIRA_TICKET
}
