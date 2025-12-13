# K8s Troubleshooter Knowledge Base System

## Overview

The knowledge base system automatically learns from your troubleshooting sessions, building a searchable repository of problems, root causes, and solutions specific to your environment.

## How It Works

### 1. During Troubleshooting

Claude helps you diagnose and fix Kubernetes issues using the k8s-troubleshooter skill.

### 2. At Session End - Write Learning Report

**Before finalization**, Claude writes a structured learning report:

**File**: `$SESSION_DIR/session-learning-report.md`

**Sections**:
- **Problem Description**: What went wrong (symptoms, errors, user impact)
- **Investigation**: How the issue was diagnosed (commands run, findings)
- **Root Cause**: Why it happened (actual underlying cause)
- **Solution**: What was changed and why it fixed the problem
- **Resources Modified**: Specific Kubernetes resources changed
- **Key Learnings**: Important insights for future reference
- **Prevention**: How to avoid this issue in the future

See [EXAMPLE_SESSION_LEARNING_REPORT.md](EXAMPLE_SESSION_LEARNING_REPORT.md) for a complete example.

### 3. Finalization Script Runs

When you run `scripts/finalize_session.sh` (or PowerShell equivalent), it:
1. Generates session summary with statistics
2. Creates consolidated manifests
3. Generates rollback scripts
4. **Calls `extract_learnings.py` to update knowledge base**

### 4. Knowledge Base Gets Updated

The `extract_learnings.py` script:
- Reads all session learning reports from `/tmp/k8s-session-summary-*.txt`
- Parses structured sections from markdown
- Categorizes problems (Memory/OOM, CrashLoopBackOff, Image Pull, Network/DNS, etc.)
- Updates `references/session-knowledge.md` with aggregated learnings

## Knowledge Base Structure

The generated knowledge base (`references/session-knowledge.md`) contains:

### Problem Categories

Problems are automatically categorized into:
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

- **Problem summary**: Brief description of what went wrong
- **Root cause**: Why it happened (truncated to 150 chars in list view)
- **Solution**: What fixed it (truncated to 150 chars in list view)
- **Resources modified**: Which K8s resources were changed

### Aggregated Insights

- **Namespace Activity**: Which namespaces have the most incidents
- **Key Learnings**: Deduplicated insights across all sessions
- **Usage Guide**: How to use the knowledge base for future troubleshooting

## Using the Knowledge Base

When troubleshooting a new issue:

1. **Open the knowledge base**: `references/session-knowledge.md`
2. **Find your problem category**: Look for similar symptoms
3. **Review past solutions**: See what worked before
4. **Apply similar fixes**: Adapt the solution to your situation
5. **Check namespace patterns**: See if your namespace has recurring issues

## Example Workflow

```bash
# 1. User reports issue
> Payment service is down, pods crashing

# 2. Claude troubleshoots using k8s-troubleshooter skill
[Investigates, finds OOMKilled errors, identifies root cause]

# 3. Claude fixes the issue
[Increases memory limits, pods recover]

# 4. Claude writes learning report
[Creates session-learning-report.md with full narrative]

# 5. User finalizes session
> finalize session

[finalize_session.sh runs]
[extract_learnings.py updates knowledge base]

# 6. Next time similar issue occurs
> Check knowledge base for OOM issues
[References/session-knowledge.md shows past memory issues and solutions]
```

## File Locations

```
plugins/k8s-troubleshooter/
├── scripts/
│   ├── extract_learnings.py          # Parses learning reports, updates KB
│   └── update_knowledge_base.sh      # Wrapper script
├── skills/k8s-troubleshooter/
│   ├── references/
│   │   └── session-knowledge.md      # Generated knowledge base (read by Claude)
│   └── scripts/
│       └── finalize_session.sh       # Calls knowledge base update
└── /tmp/k8s-troubleshooter/
    └── YYYYMMDD-HHMMSS-TICKET/
        ├── session-learning-report.md     # Your learning report
        ├── k8s-session-summary.txt        # Auto-generated stats
        └── k8s-changes.yaml               # Change tracking

# KB update also reads from:
/tmp/k8s-session-summary-*.txt  # Copied summaries for KB processing
```

## Best Practices

### Writing Good Learning Reports

✅ **DO**:
- Be specific about symptoms and error messages
- Document your investigation steps
- Explain the "why" not just the "what"
- Include concrete commands you ran
- Note prevention measures

❌ **DON'T**:
- Write generic descriptions like "fixed deployment"
- Skip root cause analysis
- Omit investigation steps
- Forget to document key learnings

### Example Comparison

**Bad Learning Report**:
```markdown
## Problem Description
Service wasn't working

## Solution
Fixed the deployment
```

**Good Learning Report**:
```markdown
## Problem Description
Payment service pods stuck in CrashLoopBackOff. Error: "OOMKilled - container exceeded memory limit"
Users seeing 503 errors on checkout page.

## Investigation
- Checked pod status: All 3 replicas in CrashLoopBackOff
- Reviewed logs: Container killed due to OOM at 512Mi limit
- Checked metrics: Memory usage spiking to 600Mi after v2.3.0 deployment
- Root cause: New Redis cache added in v2.3.0 increased memory from 300Mi to 600Mi

## Solution
Increased memory limits:
- Memory request: 256Mi → 768Mi
- Memory limit: 512Mi → 1Gi
Provides 40% headroom above typical usage.

## Key Learnings
- Always update resource limits when adding new dependencies
- Memory limits should have 30-50% headroom for production services
```

## Maintenance

### Reviewing the Knowledge Base

Periodically review `references/session-knowledge.md`:
- Look for recurring patterns
- Identify systemic issues
- Update infrastructure based on trends
- Share learnings with team

### Manual Updates

You can manually edit `references/session-knowledge.md` to:
- Add important context
- Document known gotchas
- Link to external documentation
- Add team-specific best practices

The script preserves manual edits in certain sections (check the file for guidance).

### Disabling Knowledge Base Updates

To skip KB updates:
```bash
export SKIP_KB_UPDATE=1
```

## Troubleshooting

### "No learning report found" Warning

This is normal for old sessions created before the learning report feature was added. The knowledge base will have limited information for these sessions (only metadata).

**Fix**: Next session, make sure to create `session-learning-report.md` before finalization.

### Knowledge Base Not Updating

1. Check if `extract_learnings.py` exists and is executable
2. Verify Python 3 is installed: `python3 --version`
3. Check for errors in finalization output
4. Manually run: `python3 scripts/extract_learnings.py /tmp references/session-knowledge.md`

### Knowledge Base Has Generic Entries

Old sessions without learning reports will show as "Configuration Issues" with minimal detail. This is expected. Future sessions with proper learning reports will have rich, detailed entries.

## Technical Details

### Categorization Algorithm

Problems are categorized based on keyword matching in the problem description and root cause:

```python
# Examples
"OOM" or "out of memory" → Memory / OOM Issues
"crashloop" or "crash" → Pod CrashLoopBackOff
"image pull" → Image Pull Errors
"argocd" or "sync" → ArgoCD Sync Issues
# ... etc
```

### Markdown Section Extraction

Uses regex to extract sections:
```python
pattern = r'##\s+Section Name\s*\n(.+?)(?=\n##|\Z)'
```

This works with standard markdown heading syntax.

### Knowledge Base Generation

1. Groups learnings by category
2. Shows each incident with problem/cause/solution
3. Aggregates namespace activity
4. Deduplicates key learnings
5. Generates markdown output

## Future Enhancements

- [ ] Search functionality (grep-based or web interface)
- [ ] Trend analysis and visualization
- [ ] Integration with monitoring alerts
- [ ] Automated suggestions when similar issues detected
- [ ] ML-based problem classification
- [ ] Export to team wiki/documentation
