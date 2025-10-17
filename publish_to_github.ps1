#!/usr/bin/env pwsh
# publish_to_github.ps1
# Helper: initialize a git repo (if needed) and publish the workspace to GitHub using the GitHub CLI (gh).
# Usage: run this from PowerShell in the workspace root. Requires git and gh (https://cli.github.com/).

Param()

$root = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $root

Write-Host "Publishing workspace at: $root"

$repoName = Read-Host "Enter repository name (just the repo name, or owner/repo to create under an org)"
if ([string]::IsNullOrWhiteSpace($repoName)) {
    Write-Host "Repository name is required. Exiting." -ForegroundColor Red
    exit 1
}

$visibility = Read-Host "Visibility (public or private) [public]"
if ([string]::IsNullOrWhiteSpace($visibility)) { $visibility = 'public' }
if ($visibility -notin @('public','private')) { Write-Host "Invalid visibility. Use 'public' or 'private'" -ForegroundColor Red; exit 1 }

# Quick safety scan: warn if any files exceed GitHub 100MB limit
Write-Host "Scanning for files larger than 90 MB (warning threshold)..."
$bigFiles = Get-ChildItem -Recurse -File | Where-Object { $_.Length -gt 90MB } | Sort-Object Length -Descending
if ($bigFiles) {
    Write-Host "WARNING: Found files larger than 90 MB. GitHub rejects files >100MB. Consider using Git LFS for large blobs." -ForegroundColor Yellow
    $bigFiles | ForEach-Object { Write-Host "  $($_.FullName) -> $([math]::Round($_.Length / 1MB, 2)) MB" }
    $proceed = Read-Host "Proceed anyway? (y/N)"
    if ($proceed -ne 'y' -and $proceed -ne 'Y') { Write-Host "Aborting per user request."; exit 1 }
}

# Initialize git if needed
if (-not (Test-Path .git)) {
    Write-Host "No .git found — initializing repository..."
    git init
    git add -A
    git commit -m "Initial commit" 2>$null
    if ($LASTEXITCODE -ne 0) { Write-Host "Warning: git commit may have failed (no changes?). Continuing..." -ForegroundColor Yellow }
    Write-Host "Initialized new git repository." -ForegroundColor Green
} else {
    Write-Host ".git exists — adding and committing outstanding changes (if any)."
    git add -A
    git commit -m "Prepare publish" 2>$null
}

# Ensure branch main exists
$currentBranch = git rev-parse --abbrev-ref HEAD 2>$null
if ($currentBranch -eq 'HEAD') {
    git branch -M main
}

# Check for gh
$gh = Get-Command gh -ErrorAction SilentlyContinue
if (-not $gh) {
    Write-Host "GitHub CLI (gh) is not installed or not on PATH. Install it from https://cli.github.com/" -ForegroundColor Yellow
    Write-Host "You can create a repo manually and then run: git remote add origin https://github.com/<owner>/$repoName.git; git push -u origin main" -ForegroundColor Yellow
    exit 1
}

try {
    Write-Host "Creating repository on GitHub (this may fail if it already exists)..."
    & gh repo create $repoName --$visibility --source=. --remote=origin --push
    if ($LASTEXITCODE -ne 0) { throw "gh repo create exited with code $LASTEXITCODE" }
    Write-Host "Repository created and pushed. Remote 'origin' set to the new repository." -ForegroundColor Green
} catch {
    Write-Host "gh repo create failed: $_" -ForegroundColor Red
    Write-Host "If the repo already exists, add it as a remote and push manually, e.g."
    Write-Host "  git remote add origin https://github.com/<owner>/$repoName.git; git push -u origin main"
    exit 1
}

Write-Host "Done." -ForegroundColor Green
# publish_to_github.ps1
# Helper script to initialize a git repo (if needed) and publish the workspace to GitHub using the GitHub CLI (gh).

# Usage: run this script from PowerShell in the workspace root. It will prompt for a repo name and visibility.
# Requirements: git, GitHub CLI (gh). Authenticate gh first: `gh auth login`.

$root = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $root

Write-Host "Publishing workspace at: $root"

$repoName = Read-Host "Enter repository name (just the repo name, or owner/repo to create under an org)"
if ([string]::IsNullOrWhiteSpace($repoName)) {
    Write-Host "Repository name is required. Exiting." -ForegroundColor Red
    exit 1
}

$visibility = Read-Host "Visibility (public or private) [public]"
if ([string]::IsNullOrWhiteSpace($visibility)) { $visibility = 'public' }
if ($visibility -notin @('public','private')) { Write-Host "Invalid visibility. Use 'public' or 'private'" -ForegroundColor Red; exit 1 }

# Initialize git if needed
if (-not (Test-Path .git)) {
    git init
    git add -A
    git commit -m "Initial commit"
    Write-Host "Initialized new git repository and created initial commit."
} else {
    Write-Host ".git exists — adding and committing outstanding changes."
    git add -A
    git commit -m "Prepare publish" -ErrorAction SilentlyContinue
}

# Check for gh
$gh = Get-Command gh -ErrorAction SilentlyContinue
if (-not $gh) {
    Write-Host "GitHub CLI (gh) is not installed or not on PATH. Install it from https://cli.github.com/" -ForegroundColor Yellow
    Write-Host "You can still create a repo manually on GitHub and add a remote named 'origin' then run: git push -u origin main" -ForegroundColor Yellow
    exit 1
}

# Create repo and push (uses gh to create and push current repo)
try {
    # Use gh to create the repo and push the current branch
    gh repo create $repoName --$visibility --source=. --remote=origin --push --confirm
    Write-Host "Repository created and pushed. Remote 'origin' set to the new repository." -ForegroundColor Green
} catch {
    Write-Host "gh repo create failed: $_" -ForegroundColor Red
    Write-Host "If the repo already exists, add it as a remote and push manually, e.g."
    Write-Host "  git remote add origin https://github.com/<owner>/$repoName.git; git push -u origin main"
}

