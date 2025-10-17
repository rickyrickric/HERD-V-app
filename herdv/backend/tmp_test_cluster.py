import sys
import traceback

sys.path.insert(0, r"E:/applications/finalapp/herdv")

try:
    from app import app
    from fastapi.testclient import TestClient
    import pathlib

    csv_path = pathlib.Path(__file__).parent / 'data' / 'sample.csv'
    data = csv_path.read_bytes()

    with TestClient(app) as client:
        resp = client.post('/cluster?n_clusters=4', data=data, headers={'Content-Type': 'text/csv'})
        print('STATUS', resp.status_code)
        print('BODY', resp.text)
except Exception:
    traceback.print_exc()
    sys.exit(1)
