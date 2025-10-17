# backend/app.py
from fastapi import FastAPI, UploadFile, File, Body, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse, Response
import pandas as pd
from io import BytesIO, StringIO

# Always use package-qualified imports
from backend.models.preprocess import preprocess
import numpy as np
from backend.models.cluster import run_ward, cluster_summary, herd_kpis
from backend.models.recommend import cluster_recommendations
from backend.utils.schema import REQUIRED_COLUMNS

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from scipy.cluster.hierarchy import dendrogram, ward
from sklearn.metrics import adjusted_rand_score
import csv
from reportlab.lib.pagesizes import letter
from reportlab.pdfgen import canvas
import tempfile
import os

app = FastAPI(title="HERD-V Backend", version="1.0")

# Allow cross-origin requests from dev frontends (Flutter web). In production
# you should restrict `allow_origins` to known hostnames.
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


def _read_csv_bytes(content: bytes) -> pd.DataFrame:
    """Read CSV bytes into a DataFrame with robust cleaning.

    - skipinitialspace to handle spaces after delimiters
    - strip column names
    - strip whitespace from string cells
    """
    # Use skipinitialspace to handle cases like '7. 0' where an extra space follows a comma
    df = pd.read_csv(BytesIO(content), skipinitialspace=True)
    # Normalize column names
    df.columns = [str(c).strip() for c in df.columns]
    # Trim whitespace from string columns
    for col in df.select_dtypes(include=[object]).columns:
        df[col] = df[col].astype(str).str.strip()
    return df

_last_linkage = None
_last_clusters = None
_last_means = None
_last_counts = None
_last_df = None

# ---------------- Schema Validation ----------------
@app.post("/schema/validate")
async def validate_csv(request: Request, file: UploadFile | None = File(None)):
    # Accept either a multipart upload (file) or raw CSV bytes in the request body.
    if file is not None:
        content = await file.read()
    else:
        # read raw body (useful for web clients that send the CSV bytes directly)
        content = await request.body()
    df = _read_csv_bytes(content)
    missing = [c for c in REQUIRED_COLUMNS if c not in df.columns]
    preview = df.head(10).to_dict(orient="records")
    return {"missing": missing, "preview": preview, "rows": len(df)}

# ---------------- Clustering ----------------
@app.post("/cluster")
async def cluster(
    request: Request,
    file: UploadFile | None = File(None),
    records: list[dict] | None = Body(None),
    n_clusters: int = 4,
    season: str | None = None
):
    # Support three upload modes:
    # 1) multipart/form-data with UploadFile (file)
    # 2) raw CSV bytes in the request body (useful for web clients sending text/csv)
    # 3) JSON body with `records` (list of dicts)
    if file is not None:
        content = await file.read()
        df = _read_csv_bytes(content)
    else:
        # Try raw request body bytes first if present (this covers web clients
        # that send text/csv or other content-types). If body is empty, fall
        # back to JSON `records`.
        # Debug logging to help diagnose client issues
        try:
            print('--- /cluster incoming request headers ---')
            for k, v in request.headers.items():
                print(f'{k}: {v}')
        except Exception:
            pass
        try:
            body = await request.body()
        except Exception as e:
            print('error reading body:', e)
            body = b''

        try:
            print('body length:', len(body))
        except Exception:
            pass

        if body and len(body) > 0:
            try:
                df = _read_csv_bytes(body)
            except Exception as e:
                # If CSV parse failed, return the parse error for easier debugging
                return JSONResponse({"error": "Failed to parse CSV body", "detail": str(e)}, status_code=400)
        elif records is not None:
            df = pd.DataFrame(records)
        else:
            return JSONResponse({"error": "Provide CSV file, raw CSV body, or JSON records."}, status_code=400)

    X, scaler, feature_names, df_clean = preprocess(df)
    labels = run_ward(X, n_clusters=n_clusters)
    df_labeled, means, counts = cluster_summary(df_clean, labels)
    recs = cluster_recommendations(means)

    linkage = ward(X)

    global _last_linkage, _last_clusters, _last_means, _last_counts, _last_df
    _last_linkage, _last_clusters, _last_means, _last_counts, _last_df = linkage, labels, means, counts, df_labeled

    clusters = []
    for _, m in means.iterrows():
        cid = int(m["Cluster"])
        clusters.append({
            "cluster_id": cid,
            "name": recs[cid]["name"],
            "count": int(counts.loc[counts["Cluster"] == cid, "Count"].values[0]),
            "means": {k: float(m[k]) for k in m.index if k != "Cluster"},
            "recommendation": recs[cid]["recommendation"]
        })

    assignments = df_labeled[["ID","Cluster"]].rename(columns={"Cluster":"cluster_id"}).to_dict(orient="records")
    kpis = herd_kpis(df_clean)
    # include labeled full records so frontends can show per-animal features
    labeled_records = df_labeled.to_dict(orient="records")

    return {
        "assignments": assignments,
        "clusters": clusters,
        "kpis": kpis,
        "feature_names": feature_names,
        "labeled_records": labeled_records,
    }

# ---------------- Dendrogram ----------------
@app.get("/dendrogram")
async def get_dendrogram():
    if _last_linkage is None:
        return JSONResponse({"error": "No clustering run yet."}, status_code=400)
    fig = plt.figure(figsize=(10, 6))
    dendrogram(_last_linkage, no_labels=True)
    plt.tight_layout()
    buf = BytesIO()
    fig.savefig(buf, format="png")
    plt.close(fig)
    buf.seek(0)
    return Response(content=buf.getvalue(), media_type="image/png")


@app.get("/cluster/compare")
async def compare_clusterings(ks: str = "3,4,5"):
    """Run clustering for multiple k values on the last dataset and return counts and ARI matrix.

    ks: comma-separated list of integers, e.g. '3,4,5'
    """
    if _last_df is None:
        return JSONResponse({"error": "No clustering run yet."}, status_code=400)
    try:
        ks_list = [int(k) for k in ks.split(",") if k.strip()]
    except Exception:
        return JSONResponse({"error": "Invalid ks parameter."}, status_code=400)

    # Prepare features using the same preprocess pipeline (drop any existing Cluster column)
    df_src = _last_df.copy()
    if "Cluster" in df_src.columns:
        df_src = df_src.drop(columns=["Cluster"])
    X, scaler, feature_names, df_clean = preprocess(df_src)

    labels_map = {}
    results = {}
    for k in ks_list:
        labels = run_ward(X, n_clusters=k)
        unique, counts = np.unique(labels, return_counts=True)
        results[k] = {int(u): int(c) for u, c in zip(unique, counts)}
        labels_map[k] = labels

    # Pairwise ARI
    ari = {}
    for i in ks_list:
        row = {}
        for j in ks_list:
            if i == j:
                row[j] = 1.0
            else:
                row[j] = float(adjusted_rand_score(labels_map[i], labels_map[j]))
        ari[i] = row

    return {"ks": ks_list, "counts": results, "ari": ari}


# ---------------- Boxplots / Plots ----------------
@app.get("/plots/boxplot/milk_yield")
async def boxplot_milk_yield():
    if _last_df is None:
        return JSONResponse({"error": "No clustering run yet."}, status_code=400)
    fig, ax = plt.subplots(figsize=(6, 4))
    try:
        # Use pandas boxplot grouped by Cluster
        _last_df.boxplot(column="Milk_Yield", by="Cluster", ax=ax)
        plt.title("Milk Yield by Cluster")
        plt.suptitle("")
        plt.tight_layout()
        buf = BytesIO()
        fig.savefig(buf, format="png", bbox_inches='tight')
        plt.close(fig)
        buf.seek(0)
        return Response(content=buf.getvalue(), media_type="image/png")
    finally:
        try:
            plt.close(fig)
        except Exception:
            pass


# ---------------- Export Assignments ----------------
@app.get("/export/assignments")
async def export_assignments():
    if _last_df is None:
        return JSONResponse({"error": "No clustering run yet."}, status_code=400)

    rows = _last_df[["ID", "Cluster"]].rename(columns={"Cluster": "cluster_id"}).to_dict(orient="records")
    # Write CSV to a text buffer then encode
    s = StringIO()
    writer = csv.DictWriter(s, fieldnames=["ID", "cluster_id"])
    writer.writeheader()
    writer.writerows(rows)
    data = s.getvalue().encode("utf-8")
    return Response(content=data, media_type="text/csv",
                    headers={"Content-Disposition": "attachment; filename=assignments.csv"})


 

# ---------------- Export Recommendations ----------------
@app.post("/recommendations/export")
async def export_recommendations(format: str = Body("csv")):
    if _last_means is None:
        return JSONResponse({"error": "No clustering run yet."}, status_code=400)

    recs = cluster_recommendations(_last_means)
    rows = []
    for _, m in _last_means.iterrows():
        cid = int(m["Cluster"])
        row = {"Cluster": cid, "Name": recs[cid]["name"], "Recommendation": recs[cid]["recommendation"]}
        for k in m.index:
            if k != "Cluster":
                row[k] = float(m[k])
        rows.append(row)

    if format.lower() == "csv":
        output = BytesIO()
        writer = csv.DictWriter(output, fieldnames=list(rows[0].keys()))
        writer.writeheader()
        writer.writerows(rows)
        output.seek(0)
        return Response(content=output.getvalue(), media_type="text/csv",
                        headers={"Content-Disposition": "attachment; filename=cluster_recommendations.csv"})

    tmp = tempfile.NamedTemporaryFile(delete=False, suffix=".pdf")
    c = canvas.Canvas(tmp.name, pagesize=letter)
    width, height = letter
    y = height - 50
    c.setFont("Helvetica-Bold", 14)
    c.drawString(50, y, "HERD-V Cluster Recommendations")
    y -= 30
    c.setFont("Helvetica", 10)
    for r in rows:
        text = f"Cluster {r['Cluster']} - {r['Name']}: {r['Recommendation']}"
        c.drawString(50, y, text)
        y -= 14
        if y < 80:
            c.showPage()
            y = height - 50
    c.save()
    with open(tmp.name, "rb") as f:
        pdf_bytes = f.read()
    os.unlink(tmp.name)
    return Response(content=pdf_bytes, media_type="application/pdf",
                    headers={"Content-Disposition": "attachment; filename=cluster_recommendations.pdf"})
