# backend/models/cluster.py
import numpy as np
import pandas as pd
from sklearn.cluster import AgglomerativeClustering

def run_ward(X: np.ndarray, n_clusters: int = 4):
    model = AgglomerativeClustering(linkage="ward", n_clusters=n_clusters)
    labels = model.fit_predict(X)
    return labels

def cluster_summary(df: pd.DataFrame, labels: np.ndarray):
    df = df.copy()
    df["Cluster"] = labels
    means = df.groupby("Cluster").mean(numeric_only=True).reset_index()
    counts = df.groupby("Cluster").size().reset_index(name="Count")
    return df, means, counts

def herd_kpis(df: pd.DataFrame):
    return {
        "average_Milk_Yield": float(df["Milk_Yield"].mean()),
        "average_Fertility_Score": float(df["Fertility_Score"].mean()),
        "average_Parasite_Load_Index": float(df["Parasite_Load_Index"].mean()),
        "average_Remaining_Months": float(df["Remaining_Months"].mean())
    }
