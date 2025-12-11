#!/bin/bash
# check_production_env.sh - Check for production environment and require explicit confirmation

set -euo pipefail

# Colors for warnings
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color
BOLD='\033[1m'

# Check current context for production indicators
CURRENT_CONTEXT=$(kubectl config current-context 2>/dev/null || echo "unknown")
CURRENT_NAMESPACE=$(kubectl config view --minify -o jsonpath='{..namespace}' 2>/dev/null || echo "default")
CLUSTER_URL=$(kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}' 2>/dev/null || echo "")

# Production indicators
PROD_INDICATORS=(
    "prod"
    "production"
    "prd"
    "live"
    "master"
    "docker-desktop"
)

# Check if environment is production
IS_PRODUCTION=false
DETECTION_REASON=""

for indicator in "${PROD_INDICATORS[@]}"; do
    if [[ "${CURRENT_CONTEXT,,}" == *"$indicator"* ]]; then
        IS_PRODUCTION=true
        DETECTION_REASON="Context contains '$indicator'"
        break
    fi
    if [[ "${CURRENT_NAMESPACE,,}" == *"$indicator"* ]]; then
        IS_PRODUCTION=true
        DETECTION_REASON="Namespace contains '$indicator'"
        break
    fi
    if [[ "${CLUSTER_URL,,}" == *"$indicator"* ]]; then
        IS_PRODUCTION=true
        DETECTION_REASON="Cluster URL contains '$indicator'"
        break
    fi
done

# Also check environment variable
if [[ "${K8S_ENVIRONMENT:-}" == "production" ]] || [[ "${ENVIRONMENT:-}" == "production" ]]; then
    IS_PRODUCTION=true
    DETECTION_REASON="Environment variable indicates production"
fi

# Display environment information
echo ""
echo "Current Environment Information:"
echo "================================"
echo "Context:   $CURRENT_CONTEXT"
echo "Namespace: $CURRENT_NAMESPACE"
echo "Cluster:   $CLUSTER_URL"
echo ""

if [ "$IS_PRODUCTION" = true ]; then
    # Production environment detected
    echo -e "${RED}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${RED}║                                                              ║${NC}"
    echo -e "${RED}║  ${BOLD}⚠️  WARNUNG: PRODUKTIVUMGEBUNG ERKANNT! ⚠️${NC}${RED}                 ║${NC}"
    echo -e "${RED}║                                                              ║${NC}"
    echo -e "${RED}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${YELLOW}Detection Reason: $DETECTION_REASON${NC}"
    echo ""
    echo -e "${RED}${BOLD}WICHTIG:${NC}"
    echo -e "${RED}========${NC}"
    echo "Dieser Skill darf ${BOLD}NORMALERWEISE NICHT${NC} für direkte Änderungen"
    echo "an Produktivsystemen verwendet werden!"
    echo ""
    echo "Produktivänderungen sollten ausschließlich über:"
    echo "  • Git-basierte CI/CD Pipelines"
    echo "  • ArgoCD Sync"
    echo "  • Approved Change Requests (mit Review)"
    echo "erfolgen."
    echo ""
    echo -e "${YELLOW}Nur in Notfällen (z.B. kritische Incidents) dürfen${NC}"
    echo -e "${YELLOW}direkte Produktivänderungen vorgenommen werden!${NC}"
    echo ""
    echo -e "${RED}${BOLD}Sie bestätigen mit dem Fortfahren:${NC}"
    echo "  ✗ Direkte Produktivänderungen verstoßen gegen IAC-Prinzipien"
    echo "  ✗ Alle Änderungen müssen dokumentiert und nachträglich ins Git übernommen werden"
    echo "  ✗ Sie tragen die volle Verantwortung für Produktivänderungen"
    echo "  ✗ Ein Jira-Ticket mit Incident/Change-Nummer ist zwingend erforderlich"
    echo ""
    echo -e "${BOLD}Um fortzufahren, geben Sie ein:${NC}"
    echo -e "${YELLOW}CONFIRM-PROD-CHANGES-<TICKET-ID>${NC}"
    echo ""
    echo "Beispiel: CONFIRM-PROD-CHANGES-INC-12345"
    echo ""
    echo -n "Eingabe (oder 'exit' zum Abbrechen): "
    
    read -r user_input
    
    if [[ "$user_input" == "exit" ]]; then
        echo -e "${GREEN}✓ Abgebrochen. Keine Änderungen vorgenommen.${NC}"
        exit 0
    fi
    
    if [[ "$user_input" =~ ^CONFIRM-PROD-CHANGES-[A-Z]+-[0-9]+$ ]]; then
        # Extract ticket ID
        TICKET_ID="${user_input#CONFIRM-PROD-CHANGES-}"
        export JIRA_TICKET="$TICKET_ID"
        export PRODUCTION_CONFIRMED="true"
        export PRODUCTION_CONFIRMATION_TIME="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
        
        echo ""
        echo -e "${YELLOW}⚠️  Produktivzugriff bestätigt für Ticket: $TICKET_ID${NC}"
        echo -e "${YELLOW}   Zeit: $PRODUCTION_CONFIRMATION_TIME${NC}"
        echo ""
        echo "WARNUNG: Alle Änderungen werden geloggt und müssen"
        echo "nachträglich ins Git-Repository übernommen werden!"
        echo ""
        
        # Log confirmation
        echo "PRODUCTION ACCESS CONFIRMED" >> "/tmp/k8s-prod-access-$(date +%Y%m%d).log"
        echo "Time: $PRODUCTION_CONFIRMATION_TIME" >> "/tmp/k8s-prod-access-$(date +%Y%m%d).log"
        echo "Ticket: $TICKET_ID" >> "/tmp/k8s-prod-access-$(date +%Y%m%d).log"
        echo "User: $(whoami)" >> "/tmp/k8s-prod-access-$(date +%Y%m%d).log"
        echo "Context: $CURRENT_CONTEXT" >> "/tmp/k8s-prod-access-$(date +%Y%m%d).log"
        echo "---" >> "/tmp/k8s-prod-access-$(date +%Y%m%d).log"
        
    else
        echo ""
        echo -e "${RED}✗ Ungültige Eingabe. Abgebrochen.${NC}"
        echo "Die Eingabe muss dem Format CONFIRM-PROD-CHANGES-<TICKET-ID> entsprechen."
        exit 1
    fi
else
    # Non-production environment
    echo -e "${GREEN}✓ Nicht-Produktivumgebung erkannt${NC}"
    echo ""
    echo "Sie arbeiten in einer Entwicklungs-/Test-Umgebung."
    echo "Änderungen können sicher durchgeführt werden."
    echo ""
    
    # Still ask for Jira ticket
    echo -n "Jira Ticket ID (optional, Enter zum Überspringen): "
    read -r ticket_input
    if [ -n "$ticket_input" ]; then
        export JIRA_TICKET="$ticket_input"
        echo "Ticket gesetzt: $JIRA_TICKET"
    fi
fi

echo ""
echo "Fahre mit Kubernetes-Troubleshooting fort..."
echo "============================================="
echo ""

# Export environment type for other scripts
export K8S_ENVIRONMENT_TYPE=$([ "$IS_PRODUCTION" = true ] && echo "production" || echo "development")
