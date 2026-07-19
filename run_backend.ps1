# run_backend.ps1
# Starts the HERD-V FastAPI backend.
#
# Usage:  ./run_backend.ps1
#
# The backend uses package-qualified imports (backend.models.*), so uvicorn
# must be launched from the `herdv/` directory with the module path
# `backend.app:app`. This script handles that for you.

$ErrorActionPreference = "Stop"
$root = $PSScriptRoot
$herdv = Join-Path $root "herdv"
$backend = Join-Path $herdv "backend"
$venv = Join-Path $backend ".venv"

# Create a virtual environment on first run.
if (-not (Test-Path $venv)) {
    Write-Host "Creating virtual environment in $venv ..."
    python -m venv $venv
}

# Activate it.
$activate = Join-Path $venv "Scripts\Activate.ps1"
. $activate

# Install/refresh dependencies.
Write-Host "Installing backend dependencies ..."
python -m pip install --upgrade pip | Out-Null
python -m pip install -r (Join-Path $backend "requirements.txt")

# Launch from herdv/ so `backend.app:app` resolves.
Set-Location $herdv
Write-Host "Starting HERD-V backend on http://localhost:8000 ..."
uvicorn backend.app:app --reload --host 0.0.0.0 --port 8000
