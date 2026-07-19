# run_frontend.ps1
# Fetches dependencies and launches the HERD-V Flutter app.
#
# Usage:  ./run_frontend.ps1            # runs on the default device
#         ./run_frontend.ps1 chrome     # runs on a specific device (e.g. chrome, emulator-5554)
#
# NOTE: the app talks to the backend at http://localhost:8000. On an Android
# emulator this is rewritten automatically to 10.0.2.2 by ApiClient, so start
# run_backend.ps1 first.

$ErrorActionPreference = "Stop"
$app = Join-Path $PSScriptRoot "herdv\frontend\herdv_app"

Set-Location $app
Write-Host "Fetching Flutter packages ..."
flutter pub get

if ($args.Count -gt 0) {
    flutter run -d $args[0]
} else {
    flutter run
}
