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
        
    def analyze_session(self, summary_file: Path, change_file: Path) -> Dict:
        """Analyze a single session and extract learnings."""
        learning = {
            'date': None,
            'jira_ticket': None,
            'problem_type': None,
            'resources_affected': [],
            'solution_steps': [],
            'outcome': None,
            'patterns': []
        }
        
        # Parse summary file
        if summary_file.exists():
            with open(summary_file) as f:
                content = f.read()
                
            # Extract metadata
            if match := re.search(r'Date:\s+(.+)', content):
                learning['date'] = match.group(1).strip()
            if match := re.search(r'Jira Ticket:\s+(.+)', content):
                learning['jira_ticket'] = match.group(1).strip()
            if match := re.search(r'Affected Namespaces:\s+(.+)', content):
                learning['resources_affected'] = match.group(1).strip().split()
                
        # Parse change file to understand what was done
        if change_file.exists():
            with open(change_file) as f:
                changes = list(yaml.safe_load_all(f))
                
            for change in changes:
                if change and isinstance(change, dict):
                    # Extract patterns from changes
                    if 'kind' in change:
                        resource_type = change['kind']
                        learning['solution_steps'].append({
                            'type': resource_type,
                            'action': self._infer_action(change),
                            'context': self._extract_context(change)
                        })
        
        # Infer problem type from changes
        learning['problem_type'] = self._infer_problem_type(learning['solution_steps'])
        
        return learning
    
    def _infer_action(self, manifest: Dict) -> str:
        """Infer what action was taken based on the manifest."""
        if not manifest:
            return 'unknown'
            
        # Look for common troubleshooting patterns
        if manifest.get('kind') == 'Pod':
            if 'restartPolicy' in str(manifest):
                return 'restart_policy_fix'
        elif manifest.get('kind') == 'Deployment':
            if 'replicas' in str(manifest):
                return 'scaling_adjustment'
            if 'resources' in str(manifest):
                return 'resource_limit_fix'
        
        return 'configuration_update'
    
    def _extract_context(self, manifest: Dict) -> Dict:
        """Extract relevant context from manifest."""
        context = {}
        
        if manifest.get('kind') == 'Deployment':
            spec = manifest.get('spec', {})
            context['replicas'] = spec.get('replicas')
            
            template_spec = spec.get('template', {}).get('spec', {})
            containers = template_spec.get('containers', [])
            if containers:
                context['image'] = containers[0].get('image')
                context['resources'] = containers[0].get('resources', {})
        
        return context
    
    def _infer_problem_type(self, steps: List[Dict]) -> str:
        """Infer the type of problem from solution steps."""
        if not steps:
            return 'unknown'
        
        # Pattern matching on solution steps
        actions = [step['action'] for step in steps]
        
        if 'restart_policy_fix' in actions:
            return 'pod_crashloop'
        elif 'resource_limit_fix' in actions:
            return 'resource_constraints'
        elif 'scaling_adjustment' in actions:
            return 'capacity_issue'
        
        return 'configuration_issue'
    
    def extract_patterns(self, learnings: List[Dict]) -> Dict:
        """Extract common patterns from multiple sessions."""
        patterns = {
            'problem_types': defaultdict(int),
            'common_fixes': defaultdict(list),
            'namespace_patterns': defaultdict(int),
            'success_rate_by_type': defaultdict(lambda: {'success': 0, 'total': 0})
        }
        
        for learning in learnings:
            problem_type = learning.get('problem_type', 'unknown')
            patterns['problem_types'][problem_type] += 1
            
            # Track which fixes work for which problems
            for step in learning.get('solution_steps', []):
                patterns['common_fixes'][problem_type].append(step['action'])
            
            # Track namespace patterns
            for ns in learning.get('resources_affected', []):
                patterns['namespace_patterns'][ns] += 1
        
        return patterns
    
    def generate_knowledge_base_update(self, patterns: Dict, learnings: List[Dict]) -> str:
        """Generate markdown content for knowledge base update."""
        md = f"""# K8s Troubleshooting Knowledge Base
Last Updated: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}

## Session Statistics

Total Sessions Analyzed: {len(learnings)}

## Common Problem Patterns

"""
        # Add problem type frequencies
        for problem_type, count in sorted(patterns['problem_types'].items(), 
                                         key=lambda x: x[1], reverse=True):
            md += f"### {problem_type.replace('_', ' ').title()}\n"
            md += f"Occurrences: {count}\n\n"
            
            # Add common fixes for this problem type
            fixes = patterns['common_fixes'].get(problem_type, [])
            if fixes:
                fix_counts = defaultdict(int)
                for fix in fixes:
                    fix_counts[fix] += 1
                
                md += "**Common Solutions:**\n"
                for fix, fix_count in sorted(fix_counts.items(), 
                                            key=lambda x: x[1], reverse=True):
                    md += f"- {fix.replace('_', ' ').title()} ({fix_count} times)\n"
                md += "\n"
        
        # Add namespace insights
        md += "## Namespace Activity Patterns\n\n"
        for ns, count in sorted(patterns['namespace_patterns'].items(), 
                               key=lambda x: x[1], reverse=True)[:10]:
            md += f"- `{ns}`: {count} incidents\n"
        
        md += "\n## Recent Solutions\n\n"
        # Add last 10 solutions
        for learning in learnings[-10:]:
            if learning.get('jira_ticket') and learning['jira_ticket'] != 'Not specified':
                md += f"### {learning['jira_ticket']}\n"
                md += f"Date: {learning.get('date', 'Unknown')}\n"
                md += f"Problem Type: {learning.get('problem_type', 'Unknown')}\n"
                md += f"Resources: {', '.join(learning.get('resources_affected', []))}\n\n"
        
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
    
    # Find all session files
    summary_files = list(session_dir.glob('k8s-session-summary-*.txt'))
    print(f"Found {len(summary_files)} session summaries")
    
    for summary_file in summary_files:
        # Find corresponding change file
        timestamp = summary_file.name.replace('k8s-session-summary-', '').replace('.txt', '')
        change_file = session_dir / f'k8s-changes-{timestamp}.yaml'
        
        if not change_file.exists():
            # Try to find any change file with similar timestamp
            change_files = list(session_dir.glob(f'k8s-changes-*.yaml'))
            if change_files:
                change_file = change_files[0]
        
        learning = extractor.analyze_session(summary_file, change_file)
        learnings.append(learning)
        print(f"Analyzed: {summary_file.name}")
    
    # Extract patterns
    patterns = extractor.extract_patterns(learnings)
    
    # Generate knowledge base
    kb_content = extractor.generate_knowledge_base_update(patterns, learnings)
    
    # Write output
    with open(output_file, 'w') as f:
        f.write(kb_content)
    
    print(f"\n✓ Knowledge base written to: {output_file}")
    print(f"  - Analyzed {len(learnings)} sessions")
    print(f"  - Identified {len(patterns['problem_types'])} problem types")
    print(f"  - Tracked {len(patterns['namespace_patterns'])} namespaces")

if __name__ == '__main__':
    main()
