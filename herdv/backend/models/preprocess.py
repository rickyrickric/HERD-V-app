import pandas as pd
import numpy as np
from sklearn.preprocessing import StandardScaler
from backend.utils.schema import CATEGORICAL, BOOLEAN, NUMERIC, ID_COL, REQUIRED_COLUMNS

def coerce_types(df: pd.DataFrame) -> pd.DataFrame:
    df = df.copy()
    missing = [c for c in REQUIRED_COLUMNS if c not in df.columns]
    if missing:
        raise ValueError(f"Missing columns: {missing}")
    df[ID_COL] = df[ID_COL].astype(str)
    for col in CATEGORICAL:
        df[col] = df[col].astype(str)
    for col in BOOLEAN:
        df[col] = df[col].map(
            lambda x: 1 if str(x).strip().lower() in ["1","true","yes","y","t"] else 0
        ).astype(int)
    # Clean numeric-like strings: remove internal whitespace and common thousands separators
    for col in NUMERIC:
        # convert to string, strip whitespace, remove internal spaces and commas
        df[col] = df[col].astype(str).str.strip().str.replace(r"\s+", "", regex=True).str.replace(',', '')
        # finally coerce to numeric, invalid values become NaN and will be filled later
        df[col] = pd.to_numeric(df[col], errors="coerce")
    return df

def validate_schema(df: pd.DataFrame) -> list[str]:
    issues = []
    nulls = df[NUMERIC].isna().sum()
    bad = [c for c in NUMERIC if nulls[c] > 0]
    if bad:
        issues.append(f"Non-numeric/NA values in: {bad}")
    return issues

def preprocess(df: pd.DataFrame):
    df = coerce_types(df)
    issues = validate_schema(df)
    if issues:
        df[NUMERIC] = df[NUMERIC].fillna(df[NUMERIC].median(numeric_only=True))
    X_cat = pd.get_dummies(df[CATEGORICAL], drop_first=False)
    X_bool = df[BOOLEAN]
    X_num = df[NUMERIC]
    scaler = StandardScaler()
    X_num_scaled = scaler.fit_transform(X_num)
    X = np.hstack([X_num_scaled, X_bool.values, X_cat.values])
    feature_names = NUMERIC + BOOLEAN + list(X_cat.columns)
    return X, scaler, feature_names, df
