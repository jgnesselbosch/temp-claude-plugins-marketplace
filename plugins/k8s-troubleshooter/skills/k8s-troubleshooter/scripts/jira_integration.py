#!/usr/bin/env python3
"""
jira_integration.py - Update Jira tickets with Kubernetes change information
"""

import os
import sys
import json
import argparse
from datetime import datetime
import requests
from typing import Dict, Any, Optional

# Configuration (set via environment variables)
JIRA_URL = os.getenv('JIRA_URL', 'https://jira.company.com')
JIRA_USER = os.getenv('JIRA_USER')
JIRA_TOKEN = os.getenv('JIRA_TOKEN')  # API token or password

class JiraClient:
    def __init__(self, base_url: str, username: str, token: str):
        self.base_url = base_url.rstrip('/')
        self.auth = (username, token)
        self.headers = {
            'Content-Type': 'application/json',
            'Accept': 'application/json'
        }
    
    def get_issue(self, issue_key: str) -> Dict[str, Any]:
        """Get issue details"""
        url = f"{self.base_url}/rest/api/2/issue/{issue_key}"
        response = requests.get(url, auth=self.auth, headers=self.headers)
        response.raise_for_status()
        return response.json()
    
    def add_comment(self, issue_key: str, comment: str) -> Dict[str, Any]:
        """Add comment to issue"""
        url = f"{self.base_url}/rest/api/2/issue/{issue_key}/comment"
        data = {"body": comment}
        response = requests.post(url, auth=self.auth, headers=self.headers, json=data)
        response.raise_for_status()
        return response.json()
    
    def update_issue(self, issue_key: str, fields: Dict[str, Any]) -> None:
        """Update issue fields"""
        url = f"{self.base_url}/rest/api/2/issue/{issue_key}"
        data = {"fields": fields}
        response = requests.put(url, auth=self.auth, headers=self.headers, json=data)
        response.raise_for_status()
    
    def attach_file(self, issue_key: str, file_path: str) -> Dict[str, Any]:
        """Attach file to issue"""
        url = f"{self.base_url}/rest/api/2/issue/{issue_key}/attachments"
        headers = {'X-Atlassian-Token': 'no-check'}
        
        with open(file_path, 'rb') as f:
            files = {'file': (os.path.basename(file_path), f)}
            response = requests.post(url, auth=self.auth, headers=headers, files=files)
        
        response.raise_for_status()
        return response.json()

def parse_change_file(change_file: str) -> Dict[str, Any]:
    """Parse Kubernetes change file for summary"""
    stats = {
        'total_changes': 0,
        'namespaces': set(),
        'resources': {},
        'operations': {'CREATE': 0, 'UPDATE': 0, 'DELETE': 0}
    }
    
    if not os.path.exists(change_file):
        return stats
    
    with open(change_file, 'r') as f:
        content = f.read()
        
        # Count total changes
        stats['total_changes'] = content.count('\n---\n')
        
        # Extract information from comments
        for line in content.split('\n'):
            if line.startswith('# Namespace:'):
                ns = line.split(':')[1].strip()
                if ns:
                    stats['namespaces'].add(ns)
            elif line.startswith('# Resource:'):
                resource = line.split(':')[1].strip().split('/')[0]
                stats['resources'][resource] = stats['resources'].get(resource, 0) + 1
            elif line.startswith('# Operation:'):
                op = line.split(':')[1].strip()
                if op in stats['operations']:
                    stats['operations'][op] += 1
    
    stats['namespaces'] = list(stats['namespaces'])
    return stats

def generate_jira_comment(stats: Dict[str, Any], session_info: Dict[str, Any]) -> str:
    """Generate formatted Jira comment"""
    comment = f"""h3. Kubernetes Changes Applied - {datetime.now().strftime('%Y-%m-%d %H:%M')}

*Session Information:*
* Environment: {session_info.get('environment', 'Not specified')}
* Cluster: {session_info.get('cluster', 'Not specified')}
* Applied by: Claude Code Kubernetes Troubleshooter

*Change Summary:*
* Total Changes: {stats['total_changes']}
* Operations:
** Creates: {stats['operations']['CREATE']}
** Updates: {stats['operations']['UPDATE']}
** Deletes: {stats['operations']['DELETE']}

*Affected Namespaces:*
{chr(10).join(f'* {ns}' for ns in stats['namespaces']) if stats['namespaces'] else '* None'}

*Modified Resources:*
{chr(10).join(f'* {res}: {count}' for res, count in stats['resources'].items()) if stats['resources'] else '* None'}

*Next Steps:*
# Review attached manifest file
# Merge changes to Git repository
# Verify changes in {session_info.get('environment', 'target')} environment
# Monitor application health

{{color:#de350b}}⚠️ Important: Changes must be committed to Git repository for GitOps compliance{{color}}
"""
    return comment

def main():
    parser = argparse.ArgumentParser(description='Update Jira ticket with K8s changes')
    parser.add_argument('ticket_id', help='Jira ticket ID (e.g., PROJ-123)')
    parser.add_argument('--change-file', help='Path to change file')
    parser.add_argument('--manifest-file', help='Path to final manifest file to attach')
    parser.add_argument('--environment', help='Environment name')
    parser.add_argument('--cluster', help='Cluster name')
    parser.add_argument('--comment-only', action='store_true', 
                       help='Only add comment without attaching files')
    parser.add_argument('--dry-run', action='store_true',
                       help='Show what would be done without making changes')
    
    args = parser.parse_args()
    
    # Validate credentials
    if not JIRA_USER or not JIRA_TOKEN:
        print("Error: JIRA_USER and JIRA_TOKEN environment variables must be set")
        print("Export them before running this script:")
        print("  export JIRA_USER=your.email@company.com")
        print("  export JIRA_TOKEN=your-api-token")
        sys.exit(1)
    
    # Find change file if not specified
    if not args.change_file:
        import glob
        change_files = glob.glob('/tmp/k8s-changes-*.yaml')
        if change_files:
            args.change_file = max(change_files, key=os.path.getctime)
            print(f"Using change file: {args.change_file}")
    
    # Parse changes
    stats = parse_change_file(args.change_file) if args.change_file else {}
    
    # Session information
    session_info = {
        'environment': args.environment or os.getenv('K8S_ENVIRONMENT', 'Not specified'),
        'cluster': args.cluster or os.getenv('K8S_CLUSTER', 'Not specified')
    }
    
    # Generate comment
    comment = generate_jira_comment(stats, session_info)
    
    if args.dry_run:
        print("=== DRY RUN MODE ===")
        print(f"Would update ticket: {args.ticket_id}")
        print(f"With comment:\n{comment}")
        if args.manifest_file:
            print(f"Would attach file: {args.manifest_file}")
        return
    
    # Initialize Jira client
    client = JiraClient(JIRA_URL, JIRA_USER, JIRA_TOKEN)
    
    try:
        # Verify ticket exists
        issue = client.get_issue(args.ticket_id)
        print(f"Found ticket: {issue['key']} - {issue['fields']['summary']}")
        
        # Add comment
        client.add_comment(args.ticket_id, comment)
        print(f"✓ Added comment to {args.ticket_id}")
        
        # Attach manifest file if provided
        if args.manifest_file and not args.comment_only:
            if os.path.exists(args.manifest_file):
                client.attach_file(args.ticket_id, args.manifest_file)
                print(f"✓ Attached manifest file: {args.manifest_file}")
            else:
                print(f"Warning: Manifest file not found: {args.manifest_file}")
        
        # Optionally update status or custom fields
        # client.update_issue(args.ticket_id, {'customfield_12345': 'K8s Changes Applied'})
        
        print(f"\n✓ Successfully updated Jira ticket {args.ticket_id}")
        print(f"View ticket: {JIRA_URL}/browse/{args.ticket_id}")
        
    except requests.exceptions.HTTPError as e:
        print(f"Error updating Jira: {e}")
        print(f"Response: {e.response.text}")
        sys.exit(1)
    except Exception as e:
        print(f"Unexpected error: {e}")
        sys.exit(1)

if __name__ == '__main__':
    main()
