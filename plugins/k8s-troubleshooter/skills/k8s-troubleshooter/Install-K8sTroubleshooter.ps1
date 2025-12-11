# Install-K8sTroubleshooter.ps1 - PowerShell installer for K8s-Troubleshooter Skill

param(
    [Parameter(Mandatory=$false)]
    [string]$ClaudeCodeDir,

    [Parameter(Mandatory=$false)]
    [string]$SourcePath
)

$ErrorActionPreference = "Stop"

# Configuration
$skillName = "k8s-troubleshooter"
$skillVersion = "1.0.0"

# Banner
Write-Host "======================================================" -ForegroundColor Blue
Write-Host "   K8s-Troubleshooter Skill Installer v$skillVersion" -ForegroundColor Blue
Write-Host "======================================================" -ForegroundColor Blue
Write-Host ""

# Check prerequisites
Write-Host "Checking prerequisites..." -ForegroundColor Yellow
Write-Host ""

# Check for kubectl
if (-not (Get-Command kubectl -ErrorAction SilentlyContinue)) {
    Write-Host "[!] kubectl not found" -ForegroundColor Red
    Write-Host "    kubectl is required for the skill to function" -ForegroundColor Yellow
    Write-Host "    Install from: https://kubernetes.io/docs/tasks/tools/" -ForegroundColor Yellow

    $continue = Read-Host "Continue anyway? (y/N)"
    if ($continue -ne "y" -and $continue -ne "Y") {
        exit 1
    }
} else {
    Write-Host "[OK] kubectl found" -ForegroundColor Green
}

# Check for git (optional)
if (Get-Command git -ErrorAction SilentlyContinue) {
    Write-Host "[OK] git found" -ForegroundColor Green
    $useGit = $true
} else {
    Write-Host "[!] git not found - will use alternative methods" -ForegroundColor Yellow
    $useGit = $false
}

Write-Host ""

# Determine Claude Code directory
Write-Host "Determining Claude Code installation directory..." -ForegroundColor Yellow

if (-not $ClaudeCodeDir) {
    # Try common locations
    $possibleDirs = @(
        "$env:USERPROFILE\.claude-code",
        "$env:USERPROFILE\.config\claude-code",
        "$env:LOCALAPPDATA\claude-code",
        "$env:APPDATA\claude-code"
    )

    foreach ($dir in $possibleDirs) {
        if (Test-Path $dir) {
            $ClaudeCodeDir = $dir
            break
        }
    }

    # If still not found, ask user
    if (-not $ClaudeCodeDir) {
        Write-Host "Claude Code directory not found automatically." -ForegroundColor Yellow
        $userDir = Read-Host "Enter Claude Code directory path (or press Enter for default)"

        if ($userDir) {
            $ClaudeCodeDir = $userDir
        } else {
            $ClaudeCodeDir = "$env:USERPROFILE\.claude-code"
        }
    }
}

Write-Host "[OK] Using Claude Code directory: $ClaudeCodeDir" -ForegroundColor Green

# Create skills directory if it doesn't exist
$skillsDir = Join-Path $ClaudeCodeDir "skills"
if (-not (Test-Path $skillsDir)) {
    New-Item -Path $skillsDir -ItemType Directory -Force | Out-Null
}

Write-Host ""

# Installation method
Write-Host "Select installation method:" -ForegroundColor Yellow
Write-Host "1) Install from local directory (current location)"
Write-Host "2) Install from local file/archive"
Write-Host "3) Install from URL"
Write-Host ""

$choice = Read-Host "Choice (1-3)"

$targetSkillDir = Join-Path $skillsDir $skillName

switch ($choice) {
    "1" {
        # Install from current directory
        Write-Host ""
        Write-Host "Installing from local directory..." -ForegroundColor Yellow

        if (-not $SourcePath) {
            $SourcePath = $PSScriptRoot
        }

        if (-not (Test-Path $SourcePath)) {
            Write-Host "[ERROR] Source path not found: $SourcePath" -ForegroundColor Red
            exit 1
        }

        # Copy skill files
        if (Test-Path $targetSkillDir) {
            Write-Host "Removing existing installation..." -ForegroundColor Yellow
            Remove-Item -Path $targetSkillDir -Recurse -Force
        }

        Write-Host "Copying skill files..." -ForegroundColor Yellow
        Copy-Item -Path $SourcePath -Destination $targetSkillDir -Recurse -Force

        Write-Host "[OK] Skill files copied successfully" -ForegroundColor Green
    }

    "2" {
        # Install from local file
        Write-Host ""
        $localPath = Read-Host "Enter path to skill archive or directory"

        if (-not (Test-Path $localPath)) {
            Write-Host "[ERROR] File not found: $localPath" -ForegroundColor Red
            exit 1
        }

        if ((Get-Item $localPath) -is [System.IO.DirectoryInfo]) {
            # It's a directory
            Copy-Item -Path $localPath -Destination $targetSkillDir -Recurse -Force
        } else {
            # Assume it's an archive
            Expand-Archive -Path $localPath -DestinationPath $targetSkillDir -Force
        }

        Write-Host "[OK] Copied from local file" -ForegroundColor Green
    }

    "3" {
        # Install from URL
        Write-Host ""
        $skillUrl = Read-Host "Enter URL to skill archive"

        $tempFile = Join-Path $env:TEMP "k8s-troubleshooter-skill.zip"

        try {
            Write-Host "Downloading..." -ForegroundColor Yellow
            Invoke-WebRequest -Uri $skillUrl -OutFile $tempFile

            Write-Host "Extracting..." -ForegroundColor Yellow
            Expand-Archive -Path $tempFile -DestinationPath $targetSkillDir -Force

            Remove-Item $tempFile -Force

            Write-Host "[OK] Downloaded and installed" -ForegroundColor Green
        } catch {
            Write-Host "[ERROR] Download failed: $_" -ForegroundColor Red
            exit 1
        }
    }

    default {
        Write-Host "[ERROR] Invalid choice" -ForegroundColor Red
        exit 1
    }
}

Write-Host ""

# Verify installation
$skillFile = Join-Path $targetSkillDir "SKILL.md"
if (Test-Path $skillFile) {
    Write-Host "[OK] Skill installed successfully" -ForegroundColor Green
} else {
    Write-Host "[ERROR] Installation failed - SKILL.md not found" -ForegroundColor Red
    exit 1
}

Write-Host ""

# Configuration
Write-Host "Configuration" -ForegroundColor Yellow
Write-Host "=============" -ForegroundColor Yellow
Write-Host ""

# Jira configuration
$configureJira = Read-Host "Configure Jira integration? (y/N)"
if ($configureJira -eq "y" -or $configureJira -eq "Y") {
    $jiraUrl = Read-Host "Jira URL"
    $jiraUser = Read-Host "Jira Username"
    $jiraToken = Read-Host "Jira API Token" -AsSecureString
    $jiraTokenPlain = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto(
        [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($jiraToken)
    )

    # Add to PowerShell profile
    $profileContent = @"

# K8s-Troubleshooter Jira Configuration
`$env:JIRA_URL = "$jiraUrl"
`$env:JIRA_USER = "$jiraUser"
`$env:JIRA_TOKEN = "$jiraTokenPlain"
"@

    Add-Content -Path $PROFILE -Value $profileContent
    Write-Host "[OK] Jira configuration saved to PowerShell profile" -ForegroundColor Green
}

# Create config file
$configFile = Join-Path $ClaudeCodeDir "skills-config.json"
$configData = @{
    $skillName = @{
        version = $skillVersion
        installed = (Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ")
        auto_update = $true
        config = @{
            production_check = $true
            jira_integration = $true
        }
    }
}

$configData | ConvertTo-Json -Depth 10 | Out-File -FilePath $configFile -Encoding UTF8
Write-Host "[OK] Configuration file created" -ForegroundColor Green

Write-Host ""

# Success message
Write-Host "======================================================" -ForegroundColor Green
Write-Host "      Installation completed successfully!" -ForegroundColor Green
Write-Host "======================================================" -ForegroundColor Green
Write-Host ""
Write-Host "Next steps:"
Write-Host "1. Start Claude Code: claude-code" -ForegroundColor White
Write-Host "2. Load the skill: use skill k8s-troubleshooter" -ForegroundColor White
Write-Host "3. Start troubleshooting: k8s diagnose" -ForegroundColor White
Write-Host ""
Write-Host "PowerShell Scripts Location:" -ForegroundColor Yellow
Write-Host "  $targetSkillDir\scripts\ps1\" -ForegroundColor Cyan
Write-Host ""
Write-Host "Available PowerShell Commands:" -ForegroundColor Yellow
Write-Host "  - Get-K8sHealth.ps1          # Cluster health check" -ForegroundColor Cyan
Write-Host "  - Track-K8sChange.ps1        # Track changes" -ForegroundColor Cyan
Write-Host "  - Show-K8sChanges.ps1        # Display tracked changes" -ForegroundColor Cyan
Write-Host "  - Apply-K8sWithTracking.ps1  # Apply with tracking" -ForegroundColor Cyan
Write-Host ""
Write-Host "Remember: Always follow production change procedures!" -ForegroundColor Red
