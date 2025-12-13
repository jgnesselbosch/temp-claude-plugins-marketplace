# Claude Code Integration Guide

## Was sind Skills in Claude Code?

Skills sind spezialisierte Erweiterungen, die Claude Code zusätzliche Fähigkeiten verleihen. Der k8s-troubleshooter Skill erweitert Claude Code um Kubernetes-spezifisches Wissen und Werkzeuge.

## Installation des Skills

### Option 1: Über Unternehmens-Repository (Empfohlen)

```bash
# 1. Repository klonen
git clone https://bitbucket.company.com/tools/k8s-troubleshooter-skill.git
cd k8s-troubleshooter-skill

# 2. Installer ausführen
./install.sh

# 3. Claude Code neustarten
claude-code --reload
```

### Option 2: Direkte Skill-Datei Upload

1. Laden Sie die `.skill` Datei herunter
2. In Claude Code Session:
   ```
   upload skill /path/to/k8s-troubleshooter.skill
   ```

### Option 3: Über Claude Web Interface

1. Öffnen Sie Claude.ai
2. Gehen Sie zu Settings → Skills
3. Klicken Sie auf "Upload Skill"
4. Wählen Sie `k8s-troubleshooter.skill`

## Verwendung in Claude Code

### Skill aktivieren

```bash
# Claude Code starten
$ claude-code

# Skill laden
> load skill k8s-troubleshooter
Skill 'k8s-troubleshooter' loaded successfully.

# Oder automatisch bei Problem-Erkennung
> my pod is crashing in production
[k8s-troubleshooter skill activated automatically]
```

### Typische Workflows

#### 1. Problem-Diagnose
```bash
> diagnose why my webapp pods are not starting
[k8s-troubleshooter] Checking pod status...
[k8s-troubleshooter] Running diagnostics...

# Claude führt automatisch aus:
- kubectl get pods -n production
- kubectl describe pod webapp-xxx
- kubectl logs webapp-xxx
- Analyse der Events
```

#### 2. Änderungen mit Tracking
```bash
> increase memory limit for webapp deployment to 2Gi

[k8s-troubleshooter] Current memory limit: 1Gi
[k8s-troubleshooter] Creating change manifest...
[k8s-troubleshooter] Applying with tracking...

Change tracked in: /tmp/k8s-changes-20240105-143022.yaml
✓ Deployment updated successfully
```

#### 3. Session-Zusammenfassung und Finalisierung
```bash
> show all kubernetes changes from this session

[k8s-troubleshooter] Session Summary:
- Total changes: 3
- Namespaces affected: production, staging
- Resources modified: Deployment(2), Service(1)

View details: show-k8s-changes

> finalize session

[k8s-troubleshooter] Running finalization script...
[k8s-troubleshooter] Generating session summary...
[k8s-troubleshooter] Creating consolidated manifests...
[k8s-troubleshooter] Updating knowledge base...

✓ Session finalized successfully
Files saved to: /tmp/k8s-troubleshooter/20240105-143022-PLAT-123/
```

## Befehle und Trigger-Phrasen

Der Skill reagiert auf natürliche Sprache:

| Trigger-Phrase | Aktion |
|---------------|--------|
| "diagnose pod" | Pod-Diagnose starten |
| "check tekton pipeline" | Tekton-Pipeline analysieren |
| "argocd sync issue" | ArgoCD-Probleme untersuchen |
| "show k8s changes" | Änderungen anzeigen |
| "fix deployment" | Deployment-Probleme beheben |
| "crossplane xr not working" | Crossplane XR debuggen |
| "finalize session" | Session beenden und finalisieren |
| "session complete" | Session beenden und finalisieren |
| "we're done" / "issue resolved" | Session beenden und finalisieren |

## Konfiguration

### Skills-Konfiguration in Claude Code

```yaml
# ~/.claude-code/config.yaml
skills:
  k8s-troubleshooter:
    enabled: true
    auto_activate:
      keywords:
        - kubernetes
        - k8s
        - pod
        - deployment
        - tekton
        - argocd
        - crossplane
    settings:
      production_warnings: true
      require_jira_ticket: true
      auto_backup: true
```

### Umgebungsspezifische Einstellungen

```bash
# ~/.bashrc oder ~/.zshrc

# Standard-Cluster
export CLAUDE_K8S_CONTEXT="dev-cluster"

# Produktiv-Schutz
export K8S_PRODUCTION_CONTEXTS="prod-cluster,prod-eu,prod-us"

# Jira Integration
export JIRA_URL="https://jira.company.com"
export JIRA_USER="your.email@company.com"
export JIRA_TOKEN="your-api-token"
```

## Best Practices

### 1. Immer mit Ticket arbeiten
```bash
> set jira ticket PLAT-123
> now diagnose the production issue
```

### 2. Änderungen reviewen
```bash
> show pending changes before applying
> apply changes after review
```

### 3. Session finalisieren
```bash
> finalize session
# This automatically:
# - Generates session summary
# - Creates consolidated manifests
# - Generates rollback scripts
# - Updates knowledge base
# - Displays next steps for Git commit

> update jira with session summary
```

## Integration mit anderen Tools

### Git Integration
```bash
> create branch for these k8s changes
[k8s-troubleshooter] Creating branch: feature/PLAT-123-k8s-fixes
[k8s-troubleshooter] Adding manifests to git...
[k8s-troubleshooter] Ready to push
```

### CI/CD Pipeline Trigger
```bash
> trigger deployment pipeline with these changes
[k8s-troubleshooter] Creating PR with changes...
[k8s-troubleshooter] Pipeline triggered: https://ci.company.com/job/123
```

## Sicherheitsfeatures

### Produktivumgebungs-Schutz
- Automatische Erkennung von Produktivumgebungen
- Explizite Bestätigung erforderlich
- Alle Änderungen werden geloggt
- Rollback-Skripte werden automatisch erstellt

### Audit Trail
```bash
> show audit log for this session
[k8s-troubleshooter] Audit Log:
- 14:30:22 - Environment check: production detected
- 14:30:45 - User confirmed: CONFIRM-PROD-CHANGES-INC-12345
- 14:31:10 - Change applied: deployment/webapp
- 14:31:15 - Backup created: /tmp/backup-deployment-webapp.yaml
```

## Troubleshooting

### Skill lädt nicht
```bash
# Check skill installation
$ ls ~/.claude-code/skills/
$ claude-code skill list

# Re-install
$ claude-code skill remove k8s-troubleshooter
$ claude-code skill install ./k8s-troubleshooter.skill
```

### Keine Kubernetes-Verbindung
```bash
# In Claude Code
> verify kubernetes connection
[k8s-troubleshooter] Checking kubectl...
[k8s-troubleshooter] Current context: none
[k8s-troubleshooter] Please configure kubectl first
```

### Skill-Updates
```bash
# Check for updates
> check k8s-troubleshooter updates
[k8s-troubleshooter] Current version: 1.0.0
[k8s-troubleshooter] Latest version: 1.1.0
[k8s-troubleshooter] Update available!

# Update skill
> update k8s-troubleshooter skill
```

## Support

- **Dokumentation**: https://wiki.company.com/claude-code-skills
- **Slack Channel**: #claude-code-help
- **Issue Tracker**: https://bitbucket.company.com/tools/k8s-troubleshooter-skill/issues
- **Team Email**: platform-team@company.com

## Beispiel-Session

```bash
$ claude-code

> I need to debug why our payment service is failing in production

[k8s-troubleshooter skill activated]
[PRODUCTION ENVIRONMENT DETECTED - Confirmation required]

Please confirm with: CONFIRM-PROD-CHANGES-<TICKET-ID>

> CONFIRM-PROD-CHANGES-INC-5432

[Confirmed] Proceeding with production debugging...

> check payment service pods

[Running] kubectl get pods -n production -l app=payment-service
NAME                            READY   STATUS    RESTARTS   AGE
payment-service-5d4b8c-x2kl9   0/1     Pending   0          5m
payment-service-5d4b8c-m3nf2   0/1     Pending   0          5m

[Analysis] Pods are stuck in Pending state. Checking events...

[Running] kubectl describe pod payment-service-5d4b8c-x2kl9 -n production

[Issue Found] Insufficient memory: nodes are overutilized

> show me node resources

[Running] kubectl top nodes
...

> scale down non-critical services to free resources

[Creating change manifest]
[Backing up current state]
[Applying changes with tracking]

✓ Successfully scaled down batch-processor (3→1 replicas)
✓ Payment service pods now running

> show-k8s-changes

[Session changes tracked]
1. Scaled deployment/batch-processor from 3 to 1 replicas
   Namespace: production
   Time: 2024-01-05 14:45:30

> finalize session

[Running finalization script...]

=========================================
  Kubernetes Session Finalization
=========================================

Session Summary:
================
Total Changes: 1
Affected Namespaces: production
  - Creates: 0
  - Updates: 1
  - Deletes: 0

Resource Types Modified:
  - deployment: 1

Generated Files:
================
1. Summary: /tmp/k8s-troubleshooter/20240105-144530-INC-5432/k8s-session-summary.txt
2. Final Manifests: /tmp/k8s-troubleshooter/20240105-144530-INC-5432/k8s-final-manifests.yaml
3. Rollback Script: /tmp/k8s-troubleshooter/20240105-144530-INC-5432/k8s-rollback.sh
4. Change Log: /tmp/k8s-troubleshooter/20240105-144530-INC-5432/k8s-changes.yaml

Updating knowledge base...
✓ Knowledge base updated successfully!

⚠️  CRITICAL: Diese Änderungen MÜSSEN ins Git-Repository eingepflegt werden!

Session erfolgreich abgeschlossen.
```
