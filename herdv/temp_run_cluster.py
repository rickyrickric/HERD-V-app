import sys
sys.path.append(r'E:/applications/finalapp/herdv')
from backend.models.preprocess import preprocess
from backend.models.cluster import run_ward, cluster_summary, herd_kpis
import pandas as pd
p='E:/applications/finalapp/sample_csv/sample.csv'
df=pd.read_csv(p, skipinitialspace=True)
print('columns:', list(df.columns)[:20])
try:
    X, scaler, feature_names, df_clean = preprocess(df)
    labels = run_ward(X, n_clusters=4)
    df_labeled, means, counts = cluster_summary(df_clean, labels)
    kpis = herd_kpis(df_clean)
    print('rows', len(df))
    print('kpis', kpis)
    print('first assignment sample:', df_labeled[['ID','Cluster']].head().to_dict(orient='records'))
    print('means columns:', means.columns.tolist())
except Exception as e:
    print('ERROR:', e)
