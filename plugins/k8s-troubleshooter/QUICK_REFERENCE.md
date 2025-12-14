# K8s Troubleshooter - Quick Reference

## 📍 Important File Locations

### Knowledge Base (The Output You're Looking For!)
```
~/.claude/skills/k8s-troubleshooter/session-knowledge.md
```
**This is where all learnings are accumulated after finalized sessions.**

**Note:** The knowledge base is stored in your home directory (`~/.claude/`) where Claude skills are installed, NOT in the git repository. This keeps your learnings persistent across different projects.

### Session Files (Per Session)
When you run a troubleshooting session, files are created in:
```
/tmp/k8s-troubleshooter/YYYYMMDD-HHMMSS-TICKET/
├── session-learning-report.md      # Written by Claude (your troubleshooting story)
├── k8s-session-summary.txt         # Auto-generated statistics
├── k8s-final-manifests.yaml        # Consolidated changes for GitOps
├── k8s-changes.yaml                # Change tracking log
├── k8s-rollback.sh                 # Emergency rollback script
├── backup-*.yaml                   # Backup files for each resource
└── fixed-*.yaml                    # Fixed manifests
```

### Knowledge Base Processing Files
```
/tmp/k8s-session-summary-*.txt      # Copied summaries for KB processing
```

## 🔄 Knowledge Base Update Flow

```
1. Troubleshooting Session
   └─> Claude creates: /tmp/k8s-troubleshooter/20251214-150000-TICKET-123/

2. Write Learning Report (IMPORTANT!)
   └─> Claude writes: session-learning-report.md (structured story)

3. Finalize Session
   └─> Run: bash scripts/finalize_session.sh
       ├─> Generates: k8s-session-summary.txt
       ├─> Generates: k8s-final-manifests.yaml
       ├─> Generates: k8s-rollback.sh
       └─> Calls: update_knowledge_base.sh

4. Knowledge Base Update
   └─> Run: update_knowledge_base.sh
       └─> Calls: extract_learnings.py /tmp ~/.claude/skills/k8s-troubleshooter/session-knowledge.md
           ├─> Reads: /tmp/k8s-session-summary-*.txt (for metadata)
           ├─> Reads: /tmp/k8s-troubleshooter/*/session-learning-report.md (for rich content)
           └─> Writes: ~/.claude/skills/k8s-troubleshooter/session-knowledge.md

5. Knowledge Base Ready!
   └─> View: cat ~/.claude/skills/k8s-troubleshooter/session-knowledge.md
```

## 🎯 Quick Commands

### View the Knowledge Base
```bash
# View the knowledge base
cat ~/.claude/skills/k8s-troubleshooter/session-knowledge.md

# Or use less for pagination
less ~/.claude/skills/k8s-troubleshooter/session-knowledge.md

# Search for specific problems
grep -A 10 "Memory / OOM" ~/.claude/skills/k8s-troubleshooter/session-knowledge.md
```

### Manually Update Knowledge Base
```bash
# If you have session files in /tmp
cd plugins/k8s-troubleshooter
bash scripts/update_knowledge_base.sh
```

### View Session Files
```bash
# List all sessions
ls -la /tmp/k8s-troubleshooter/

# View latest session
cd $(ls -dt /tmp/k8s-troubleshooter/*/ | head -1)
ls -la

# View learning report from latest session
cat $(ls -dt /tmp/k8s-troubleshooter/*/ | head -1)/session-learning-report.md
```

### Test the Knowledge Base Extraction
```bash
# Create a test learning report
mkdir -p /tmp/k8s-troubleshooter/test-session
cat > /tmp/k8s-troubleshooter/test-session/session-learning-report.md <<'EOF'
# Session Learning Report

## Problem Description
Test problem: Pod not starting

## Investigation
Checked pod status and logs

## Root Cause
Missing environment variable

## Solution
Added environment variable

## Resources Modified
- deployment/test-app in default namespace

## Key Learnings
- Always verify environment variables
- Check pod logs first

## Prevention
- Add env var validation in CI/CD
EOF

# Create summary file
cat > /tmp/k8s-troubleshooter/test-session/k8s-session-summary.txt <<EOF
Kubernetes Troubleshooting Session Summary
==========================================
Date: $(date)
Jira Ticket: TEST-123
Affected Namespaces: default
EOF

# Copy summary to /tmp for KB processing
cp /tmp/k8s-troubleshooter/test-session/k8s-session-summary.txt /tmp/k8s-session-summary-test-TEST-123.txt

# Run extraction
cd plugins/k8s-troubleshooter
python3 scripts/extract_learnings.py /tmp ~/.claude/skills/k8s-troubleshooter/session-knowledge.md

# View result
cat ~/.claude/skills/k8s-troubleshooter/session-knowledge.md
```

## 📊 What the Knowledge Base Contains

After sessions are finalized, the knowledge base will have:

### Problem Categories
- Memory / OOM Issues
- Pod CrashLoopBackOff
- Image Pull Errors
- Pod Scheduling Issues
- Network / DNS Issues
- ArgoCD Sync Issues
- Tekton Pipeline Issues
- Crossplane Issues
- Storage / PVC Issues
- RBAC / Permission Issues
- Configuration Issues

### For Each Problem
- Problem description (what went wrong)
- Root cause (why it happened)
- Solution (what fixed it)
- Resources modified
- Ticket reference

### Aggregated Data
- Namespace activity patterns
- Key learnings across all sessions
- Usage instructions

## 🐛 Troubleshooting

### Knowledge Base Not Updating?

1. **Check if session learning report exists:**
   ```bash
   ls /tmp/k8s-troubleshooter/*/session-learning-report.md
   ```
   If missing: Claude didn't write it before finalization

2. **Check if summary file was copied:**
   ```bash
   ls /tmp/k8s-session-summary-*.txt
   ```
   If missing: finalize_session.sh didn't run or failed

3. **Manually run the update:**
   ```bash
   cd plugins/k8s-troubleshooter
   bash scripts/update_knowledge_base.sh
   ```

4. **Check Python script directly:**
   ```bash
   cd plugins/k8s-troubleshooter
   python3 scripts/extract_learnings.py /tmp references/session-knowledge.md
   ```

### Knowledge Base Has Generic Entries?

If you see entries like:
```
### Configuration Issues
Occurrences: 1
```

**Cause**: No `session-learning-report.md` was created for that session.

**Fix**: Make sure Claude writes the learning report before finalization in future sessions.

## 📝 Example Session Workflow

```bash
# 1. User asks Claude to troubleshoot
> my payment service pods are crashing

# 2. Claude investigates and fixes
[... troubleshooting happens ...]

# 3. Claude writes learning report
[Claude creates: /tmp/k8s-troubleshooter/20251214-150000-TICKET/session-learning-report.md]

# 4. User finalizes session
> finalize session
[finalize_session.sh runs]
[Knowledge base updated]

# 5. Check the knowledge base
cat ~/.claude/skills/k8s-troubleshooter/session-knowledge.md
```

## 🔗 Related Files

- **[KNOWLEDGE_BASE_README.md](KNOWLEDGE_BASE_README.md)** - Full documentation
- **[EXAMPLE_SESSION_LEARNING_REPORT.md](EXAMPLE_SESSION_LEARNING_REPORT.md)** - Example learning report
- **[SKILL.md](skills/k8s-troubleshooter/SKILL.md#L464-L558)** - Session finalization instructions
- **[CHANGES_SUMMARY.md](../../CHANGES_SUMMARY.md#L124)** - Knowledge base improvements
