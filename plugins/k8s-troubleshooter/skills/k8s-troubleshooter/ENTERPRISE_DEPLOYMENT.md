# K8s-Troubleshooter Skill - Enterprise Deployment Guide

## 🚀 Deployment über Bitbucket

Diese Anleitung beschreibt, wie der K8s-Troubleshooter Skill unternehmensweit über Bitbucket bereitgestellt wird.

## Repository-Struktur

```
bitbucket.company.com/tools/k8s-troubleshooter-skill/
├── README.md                      # Diese Datei
├── k8s-troubleshooter.skill       # Kompilierter Skill (Binary)
├── install.sh                     # Automatisches Setup-Skript
├── install.ps1                    # Windows PowerShell Setup
├── version.json                   # Versionsinformation
├── CHANGELOG.md                   # Änderungshistorie
├── docs/
│   ├── CLAUDE_CODE_SETUP.md      # Claude Code Integration
│   ├── USAGE_GUIDE.md            # Benutzerhandbuch
│   └── TROUBLESHOOTING.md        # Fehlerbehebung
└── source/                        # Quellcode (optional)
    └── k8s-troubleshooter/        # Skill-Entwicklungsdateien
```

## Installation für Claude Code

### Methode 1: Automatische Installation (Empfohlen)

```bash
# Linux/Mac
curl -sSL https://bitbucket.company.com/tools/k8s-troubleshooter-skill/raw/main/install.sh | bash

# Windows PowerShell
iwr -Uri https://bitbucket.company.com/tools/k8s-troubleshooter-skill/raw/main/install.ps1 | iex
```

### Methode 2: Manuelle Installation

1. **Skill herunterladen:**
   ```bash
   git clone https://bitbucket.company.com/tools/k8s-troubleshooter-skill.git
   cd k8s-troubleshooter-skill
   ```

2. **In Claude Code installieren:**
   ```bash
   # Skill-Datei in Claude Code Verzeichnis kopieren
   cp k8s-troubleshooter.skill ~/.claude-code/skills/
   
   # Oder direkt über Claude Code CLI
   claude-code skill install ./k8s-troubleshooter.skill
   ```

3. **Konfiguration prüfen:**
   ```bash
   claude-code skill list | grep k8s-troubleshooter
   ```

### Methode 3: Direkte URL-Installation in Claude Code

In Claude Code Session:
```bash
claude-code skill install https://bitbucket.company.com/tools/k8s-troubleshooter-skill/raw/main/k8s-troubleshooter.skill
```

## Claude Code Integration

### Aktivierung in Claude Code

1. **Starten Sie Claude Code:**
   ```bash
   claude-code --model claude-3-sonnet
   ```

2. **Skill aktivieren:**
   ```
   > use skill k8s-troubleshooter
   K8s-Troubleshooter skill loaded successfully
   ```

3. **Verfügbare Befehle anzeigen:**
   ```
   > help k8s-troubleshooter
   ```

### Verwendung in Claude Code

```bash
# Session starten
> k8s troubleshoot

# Spezifische Namespace-Probleme
> diagnose pod issues in namespace production

# Änderungen anzeigen
> show-k8s-changes

# Session beenden und Manifeste generieren
> finalize k8s session
```

## 🔒 Sicherheit & Compliance

### Produktivumgebungs-Schutz

Der Skill enthält mehrfache Sicherheitsmechanismen:

1. **Automatische Umgebungserkennung**
2. **Explizite Bestätigung für Produktivzugriff erforderlich**
3. **Vollständiges Audit-Logging**
4. **Jira-Ticket-Pflicht für Produktivänderungen**

### Berechtigungsmanagement

```yaml
# .claude-code/config.yaml
skills:
  k8s-troubleshooter:
    enabled: true
    environments:
      production:
        require_approval: true
        allowed_users:
          - user1@company.com
          - user2@company.com
        allowed_groups:
          - platform-team
          - sre-team
      development:
        require_approval: false
        allowed_groups:
          - all-developers
```

## 🔄 Updates & Versionierung

### Automatische Updates

```bash
# Update-Check
claude-code skill update-check k8s-troubleshooter

# Update durchführen
claude-code skill update k8s-troubleshooter
```

### Manuelle Updates

```bash
cd ~/.claude-code/skills/
curl -O https://bitbucket.company.com/tools/k8s-troubleshooter-skill/raw/main/k8s-troubleshooter.skill
```

## 📋 Voraussetzungen

- **Claude Code CLI** installiert
- **kubectl** konfiguriert
- **Kubernetes Cluster Zugriff**
- Optional: **tkn** (Tekton CLI)
- Optional: **argocd** CLI
- **Jira API Token** für Ticket-Integration

## 🛠️ Konfiguration

### Umgebungsvariablen

```bash
# ~/.bashrc oder ~/.zshrc
export JIRA_URL="https://jira.company.com"
export JIRA_USER="your.email@company.com"
export JIRA_TOKEN="your-api-token"

# Optional: Standard-Umgebung
export K8S_ENVIRONMENT="development"
```

### Claude Code Konfiguration

```json
// ~/.claude-code/skills.json
{
  "k8s-troubleshooter": {
    "version": "1.0.0",
    "auto_update": true,
    "config": {
      "default_namespace": "default",
      "production_check": true,
      "jira_integration": true,
      "git_repo": "bitbucket.company.com/k8s/manifests"
    }
  }
}
```

## 📞 Support & Feedback

- **Internes Wiki:** https://wiki.company.com/k8s-troubleshooter
- **Slack Channel:** #platform-tools
- **Issue Tracker:** https://bitbucket.company.com/tools/k8s-troubleshooter-skill/issues
- **Team:** platform-team@company.com

## Lizenz

Internes Tool - Nur für Mitarbeiter der Company GmbH
