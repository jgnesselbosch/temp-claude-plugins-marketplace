#!/usr/bin/env python3
"""
Extract learnings from k8s troubleshooting sessions and update the knowledge base.
This script analyzes completed sessions and identifies patterns, solutions, and best practices.
"""

import sys
import yaml
import json
import re
from pathlib import Path
from datetime import datetime
from collections import defaultdict
from typing import Dict, List, Tuple

class SessionLearningExtractor:
    def __init__(self, session_dir: Path):
        self.session_dir = session_dir
        self.patterns = defaultdict(list)
        self.solutions = defaultdict(list)
        
    def analyze_session(self, summary_file: Path, learning_report: Path = None) -> Dict:
        """Analyze a single session and extract learnings."""
        learning = {
            'date': None,
            'jira_ticket': None,
            'problem_description': None,
            'investigation': None,
            'root_cause': None,
            'solution': None,
            'resources_modified': [],
            'key_learnings': [],
            'prevention': None,
            'namespaces': []
        }

        # Parse summary file for metadata
        if summary_file.exists():
            with open(summary_file) as f:
                content = f.read()

            # Extract metadata
            if match := re.search(r'Date:\s+(.+)', content):
                learning['date'] = match.group(1).strip()
            if match := re.search(r'Jira Ticket:\s+(.+)', content):
                learning['jira_ticket'] = match.group(1).strip()
            if match := re.search(r'Affected Namespaces:\s+(.+)', content):
                learning['namespaces'] = match.group(1).strip().split()

        # Parse learning report if it exists (this is the rich content!)
        if learning_report and learning_report.exists():
            with open(learning_report) as f:
                content = f.read()

            # Extract structured sections
            learning['problem_description'] = self._extract_section(content, 'Problem Description')
            learning['investigation'] = self._extract_section(content, 'Investigation')
            learning['root_cause'] = self._extract_section(content, 'Root Cause')
            learning['solution'] = self._extract_section(content, 'Solution')
            learning['prevention'] = self._extract_section(content, 'Prevention')

            # Extract resources modified (bullet list)
            resources_section = self._extract_section(content, 'Resources Modified')
            if resources_section:
                learning['resources_modified'] = [
                    line.strip('- ').strip()
                    for line in resources_section.split('\n')
                    if line.strip().startswith('-')
                ]

            # Extract key learnings (bullet list)
            learnings_section = self._extract_section(content, 'Key Learnings')
            if learnings_section:
                learning['key_learnings'] = [
                    line.strip('- ').strip()
                    for line in learnings_section.split('\n')
                    if line.strip().startswith('-')
                ]

        return learning

    def _extract_section(self, content: str, section_name: str) -> str:
        """Extract a section from the learning report markdown."""
        pattern = rf'##\s+{re.escape(section_name)}\s*\n(.+?)(?=\n##|\Z)'
        match = re.search(pattern, content, re.DOTALL)
        if match:
            return match.group(1).strip()
        return None
    
    def _categorize_problem(self, learning: Dict) -> str:
        """Categorize the problem type based on description and root cause."""
        problem_desc = (learning.get('problem_description') or '').lower()
        root_cause = (learning.get('root_cause') or '').lower()
        combined = problem_desc + ' ' + root_cause

        # Pattern matching on problem description
        if 'oom' in combined or 'out of memory' in combined or 'memory limit' in combined:
            return 'Memory / OOM Issues'
        elif 'crashloop' in combined or 'crash' in combined:
            return 'Pod CrashLoopBackOff'
        elif 'image' in combined and ('pull' in combined or 'not found' in combined):
            return 'Image Pull Errors'
        elif 'pending' in combined or 'scheduling' in combined:
            return 'Pod Scheduling Issues'
        elif 'network' in combined or 'dns' in combined or 'connection' in combined:
            return 'Network / DNS Issues'
        elif 'argocd' in combined or 'sync' in combined:
            return 'ArgoCD Sync Issues'
        elif 'tekton' in combined or 'pipeline' in combined:
            return 'Tekton Pipeline Issues'
        elif 'crossplane' in combined:
            return 'Crossplane Issues'
        elif 'storage' in combined or 'pvc' in combined or 'volume' in combined:
            return 'Storage / PVC Issues'
        elif 'permission' in combined or 'rbac' in combined or 'forbidden' in combined:
            return 'RBAC / Permission Issues'

        return 'Configuration Issues'
    
    def extract_patterns(self, learnings: List[Dict]) -> Dict:
        """Extract common patterns from multiple sessions."""
        patterns = {
            'problem_categories': defaultdict(list),
            'namespace_patterns': defaultdict(int),
            'all_learnings': []
        }

        for learning in learnings:
            # Categorize this problem
            category = self._categorize_problem(learning)

            # Group learnings by category
            patterns['problem_categories'][category].append(learning)

            # Track namespace patterns
            for ns in learning.get('namespaces', []):
                patterns['namespace_patterns'][ns] += 1

            # Collect all key learnings
            patterns['all_learnings'].extend(learning.get('key_learnings', []))

        return patterns
    
    def generate_knowledge_base_update(self, patterns: Dict, learnings: List[Dict]) -> str:
        """Generate markdown content for knowledge base update."""
        md = f"""# K8s Troubleshooting Knowledge Base
Last Updated: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}

## Session Statistics

Total Sessions Analyzed: {len(learnings)}

## Problem Categories and Solutions

"""
        # Add each problem category with its solutions
        for category, category_learnings in sorted(patterns['problem_categories'].items(),
                                                   key=lambda x: len(x[1]), reverse=True):
            md += f"### {category}\n\n"
            md += f"**Occurrences:** {len(category_learnings)} session(s)\n\n"

            # Show each incident in this category
            for learning in category_learnings:
                ticket = learning.get('jira_ticket', 'N/A')
                if ticket and ticket != 'Not specified':
                    md += f"#### {ticket}\n"
                else:
                    md += f"#### Session from {learning.get('date', 'Unknown')}\n"

                # Problem description
                if learning.get('problem_description'):
                    md += f"\n**Problem:** {learning['problem_description'][:200]}"
                    if len(learning['problem_description']) > 200:
                        md += "..."
                    md += "\n\n"

                # Root cause
                if learning.get('root_cause'):
                    md += f"**Root Cause:** {learning['root_cause'][:150]}"
                    if len(learning['root_cause']) > 150:
                        md += "..."
                    md += "\n\n"

                # Solution summary
                if learning.get('solution'):
                    md += f"**Solution:** {learning['solution'][:150]}"
                    if len(learning['solution']) > 150:
                        md += "..."
                    md += "\n\n"

                # Resources modified
                if learning.get('resources_modified'):
                    md += "**Resources Modified:**\n"
                    for resource in learning['resources_modified'][:3]:  # Limit to 3
                        md += f"- {resource}\n"
                    md += "\n"

                md += "---\n\n"

        # Add namespace insights
        md += "## Namespace Activity Patterns\n\n"
        if patterns['namespace_patterns']:
            for ns, count in sorted(patterns['namespace_patterns'].items(),
                                   key=lambda x: x[1], reverse=True)[:10]:
                md += f"- `{ns}`: {count} incident(s)\n"
        else:
            md += "*No namespace data available yet*\n"

        # Add aggregated key learnings
        md += "\n## Key Learnings Across All Sessions\n\n"
        if patterns['all_learnings']:
            # Deduplicate and show unique learnings
            unique_learnings = list(set(patterns['all_learnings']))
            for learning_item in unique_learnings[:20]:  # Top 20
                md += f"- {learning_item}\n"
        else:
            md += "*No learnings captured yet*\n"

        md += "\n---\n\n"
        md += "## How to Use This Knowledge Base\n\n"
        md += "When troubleshooting similar issues:\n"
        md += "1. Find your problem category above\n"
        md += "2. Review past root causes and solutions\n"
        md += "3. Apply similar fixes to your situation\n"
        md += "4. Check namespace-specific patterns\n\n"

        return md

def main():
    if len(sys.argv) < 2:
        print("Usage: extract_learnings.py <session_dir> [output_file]")
        print("\nExample:")
        print("  extract_learnings.py /tmp knowledge-base.md")
        sys.exit(1)
    
    session_dir = Path(sys.argv[1])
    output_file = Path(sys.argv[2]) if len(sys.argv) > 2 else Path('session-knowledge.md')
    
    if not session_dir.exists():
        print(f"Error: Directory {session_dir} not found")
        sys.exit(1)
    
    extractor = SessionLearningExtractor(session_dir)
    learnings = []

    # Find all session summary files (both old and new locations)
    summary_files = list(session_dir.glob('k8s-session-summary-*.txt'))

    # Also check for session directories (both directly in session_dir and in k8s-troubleshooter subdir)
    session_dirs = [d for d in session_dir.glob('*') if d.is_dir() and d.name.startswith('2')]

    # Also check in k8s-troubleshooter subdirectory
    k8s_troubleshooter_dir = session_dir / 'k8s-troubleshooter'
    if k8s_troubleshooter_dir.exists():
        session_dirs.extend([d for d in k8s_troubleshooter_dir.glob('*') if d.is_dir() and d.name.startswith('2')])

    for session_subdir in session_dirs:
        summary_in_dir = session_subdir / 'k8s-session-summary.txt'
        if summary_in_dir.exists():
            summary_files.append(summary_in_dir)

    print(f"Found {len(summary_files)} session summaries")

    for summary_file in summary_files:
        # Try to find corresponding learning report
        learning_report = None

        # Check if summary is in a session directory
        if summary_file.parent != session_dir:
            # It's in a subdirectory - look for learning report there
            learning_report = summary_file.parent / 'session-learning-report.md'
        else:
            # Old format - try to match by timestamp
            timestamp = summary_file.name.replace('k8s-session-summary-', '').replace('.txt', '')
            # Look for session directory with this timestamp
            for session_subdir in session_dirs:
                if timestamp in session_subdir.name:
                    learning_report = session_subdir / 'session-learning-report.md'
                    break

        learning = extractor.analyze_session(summary_file, learning_report)
        learnings.append(learning)

        if learning_report and learning_report.exists():
            print(f"✓ Analyzed: {summary_file.name} (with learning report)")
        else:
            print(f"⚠ Analyzed: {summary_file.name} (no learning report found)")

    # Extract patterns
    patterns = extractor.extract_patterns(learnings)

    # Generate knowledge base
    kb_content = extractor.generate_knowledge_base_update(patterns, learnings)

    # Write output
    with open(output_file, 'w') as f:
        f.write(kb_content)

    print(f"\n✓ Knowledge base written to: {output_file}")
    print(f"  - Analyzed {len(learnings)} sessions")
    print(f"  - Identified {len(patterns['problem_categories'])} problem categories")
    print(f"  - Tracked {len(patterns['namespace_patterns'])} namespaces")
    print(f"  - Collected {len(patterns['all_learnings'])} key learnings")

if __name__ == '__main__':
    main()
