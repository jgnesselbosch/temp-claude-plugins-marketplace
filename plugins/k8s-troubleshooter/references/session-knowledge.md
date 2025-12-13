# K8s Troubleshooting Knowledge Base

Last Updated: 2025-12-13 10:30:00

This file contains learnings extracted from past troubleshooting sessions. Claude references this when diagnosing similar issues.

## Session Statistics

Total Sessions Analyzed: 0

*This file will be automatically populated after your first troubleshooting sessions.*

## Common Problem Patterns

### How This Knowledge Base Works

When you complete troubleshooting sessions using this skill, the `update_knowledge_base.sh` script analyzes:

1. **Problem Types**: What kinds of issues you've encountered
2. **Solution Patterns**: Which fixes worked for which problems
3. **Resource Patterns**: Which namespaces/resources are most affected
4. **Success Metrics**: Which approaches have the highest success rate

### Pattern Recognition

As sessions accumulate, Claude will learn to recognize patterns like:

- **Pod CrashLoopBackOff** → Common causes and fixes specific to your environment
- **Resource Constraints** → Typical resource limit adjustments that work
- **ArgoCD Sync Issues** → Namespace-specific configuration problems
- **Network Issues** → Common DNS or service mesh problems

### Using This Knowledge

When troubleshooting, Claude will:

1. Check if the current problem matches known patterns
2. Suggest solutions that worked in similar past cases
3. Highlight namespace-specific quirks discovered previously
4. Warn about common pitfalls encountered before

## Namespace Activity Patterns

*Will be populated with your most active namespaces and their typical issues*

## Recent Solutions

*Will contain the last 10 successfully resolved issues for quick reference*

---

## Manual Additions

You can also manually add important learnings here:

### Custom Best Practices

Add any environment-specific knowledge here:

```markdown
### ArgoCD Auto-Sync Issues in Production

**Pattern**: ArgoCD fails to auto-sync certain namespaces
**Root Cause**: Namespace label missing `argocd.argoproj.io/instance`
**Solution**: Always verify namespace labels before deploying apps
**Affected Namespaces**: production-*, staging-*
```

### Known Gotchas

Document recurring issues that aren't captured by automation:

- Legacy deployments in `legacy-*` namespaces use deprecated API versions
- Crossplane XRs in `infra` namespace require manual refresh after Azure changes
- Tekton pipelines require specific ServiceAccount permissions per namespace

---

## Integration Notes

This knowledge base is automatically updated by:
- `scripts/update_knowledge_base.sh` (called from finalize_session.sh)
- `scripts/extract_learnings.py` (analyzes session files)

To manually update:
```bash
./scripts/update_knowledge_base.sh
```

To disable auto-updates, set in your environment:
```bash
export SKIP_KB_UPDATE=1
```
