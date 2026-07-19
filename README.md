# HERD-V

Cattle-herd clustering and insights. A Flutter app (`herdv_app`) that groups
animals into herds using Ward hierarchical clustering, backed by a FastAPI +
scikit-learn service. Clustering can run either against the backend or fully
offline inside the app.

## Layout

```
herdv/
├─ backend/                 FastAPI + pandas/scikit-learn (Ward clustering)
│  ├─ app.py                API endpoints
│  ├─ models/               preprocess, cluster, recommend
│  ├─ utils/schema.py       required CSV columns
│  └─ requirements.txt
└─ frontend/herdv_app/      Flutter app (Android / iOS / web / desktop)
```

## Requirements

- Python 3.10+ (for the backend)
- Flutter 3.x with the Dart SDK (for the app)

## Running (Windows / PowerShell)

Two helper scripts live at the repo root. Start the backend first, then the app.

```powershell
# Terminal 1 — backend (creates a venv, installs deps, serves on :8000)
./run_backend.ps1

# Terminal 2 — Flutter app
./run_frontend.ps1            # default device
./run_frontend.ps1 chrome     # or a named device, e.g. chrome / emulator-5554
```

`run_backend.ps1` creates `herdv/backend/.venv` on first run and installs
`requirements.txt` into it, so subsequent runs are fast.

## Running manually

Backend — must launch from `herdv/` so the `backend.app:app` package path
resolves:

```powershell
cd herdv
python -m venv backend/.venv
backend/.venv/Scripts/Activate.ps1
pip install -r backend/requirements.txt
uvicorn backend.app:app --reload --port 8000
```

App:

```powershell
cd herdv/frontend/herdv_app
flutter pub get
flutter run
```

## Notes

- The app targets `http://localhost:8000`. On an Android emulator, `ApiClient`
  automatically rewrites `localhost` to `10.0.2.2` to reach the host machine.
- Uploaded CSVs must contain the columns listed in
  `herdv/backend/utils/schema.py` (`ID`, `Breed`, `Age`, `Weight_kg`,
  `Milk_Yield`, ...). A sample lives in `sample_csv/sample.csv`.
- The backend keeps the most recent clustering result in module-level state to
  serve the dendrogram / export / plot endpoints. This is single-user by
  design — do not expose it to multiple concurrent users as-is.
