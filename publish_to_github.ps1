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

