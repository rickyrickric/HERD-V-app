HERD‑V Flutter + FastAPI application

Overview
--------
This repository contains a Flutter frontend (HERD‑V mobile/web app) and a FastAPI backend for clustering herd animals and producing insights and exports.

Project layout (key folders)
- backend/ — Python FastAPI backend (clustering, plots, exports). Run with `uvicorn backend.app:app --host 0.0.0.0 --port 8000 --reload`.
- frontend/herdv_app/ — Flutter app (Dart). Run with `flutter run` or `flutter run -d web-server`.
- sample_csv/ — contains `sample.csv` and `cluster_result.json` for testing.

Quickstart (host machine)
1. Start backend (Python environment)
	- Create venv and install dependencies listed in `backend/requirements.txt`.
	- Run:
	  ```powershell
	  cd E:\applications\finalapp\herdv\backend
	  python -m venv .venv
	  .\.venv\Scripts\Activate.ps1
	  pip install -r requirements.txt
	  uvicorn backend.app:app --host 0.0.0.0 --port 8000 --reload
	  ```
	- Backend listens on port 8000.

2. Run the Flutter frontend
	- Ensure Flutter SDK is installed and an emulator/device is available.
	- From frontend folder:
	  ```powershell
	  cd E:\applications\finalapp\herdv\frontend\herdv_app
	  flutter pub get
	  flutter run
	  ```
	- Note: when running on Android emulator, `localhost` refers to the emulator. The app includes an automatic mapping to `10.0.2.2` for emulator networking.

CSV sample
----------
- `sample_csv/sample.csv` — example herd dataset used by the app for clustering.

What I changed during debugging (summary)
----------------------------------------
- Added fallback file-picker handling for Android (read file bytes from path when in-memory bytes are absent).
- Implemented client-side K-means fallback for offline clustering.
- Updated UI for Animals list and Cluster Insights.
- Added an SVG cow asset for optional icon usage (not enabled by default).
- Dendrogram UI was removed per request.

Reverting changes
-----------------
- This workspace does not contain a Git history. Because of that, automated full revert is not possible here. If you have a backup or upstream repository, revert by checking out the original files there.
- If you want me to revert specific file edits I made in this session, tell me which files and I will attempt to restore them to a prior state (based on context or re-generating original versions).

Publishing to GitHub
--------------------
- I included a helper PowerShell script `publish_to_github.ps1` (workspace root) to create a repo and push the current files using the GitHub CLI (`gh`). The script will initialize git if needed and can create a public or private repo.

How to publish (using the script)
--------------------------------
1. Install Git and GitHub CLI (`gh`) and authenticate `gh auth login`.
2. From PowerShell run (from workspace root):
	```powershell
	.\publish_to_github.ps1
	```
	The script prompts for a repository name and whether the repo should be public or private.

Support
-------
Tell me whether you want me to:
- Revert all changes I made (I will need either an origin/backup or explicit confirmation to overwrite with a chosen prior state).
- Keep current code and help you push the repo now (I can prepare and test the push script). 

If you'd like me to proceed with publishing, provide the GitHub repository name (or I can prompt for it interactively) and confirm whether the repo should be public or private.
