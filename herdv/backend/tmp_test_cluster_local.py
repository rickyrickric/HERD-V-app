import sys
import traceback
from pathlib import Path

sys.path.insert(0, r"E:/applications/finalapp/herdv")

try:
    from app import app
    from fastapi.testclient import TestClient

    csv_path = Path(r'E:/applications/finalapp/sample_csv/sample.csv')
    if not csv_path.exists():
        print('Sample CSV not found at', csv_path)
        raise SystemExit(1)

    data = csv_path.read_bytes()

    with TestClient(app) as client:
        resp = client.post('/cluster?n_clusters=4', data=data, headers={'Content-Type': 'text/csv'})
        print('STATUS', resp.status_code)
        print('BODY', resp.text)
except Exception:
    traceback.print_exc()
    sys.exit(1)
