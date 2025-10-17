import pandas as pd
from io import BytesIO


def _read_csv_bytes(content: bytes) -> pd.DataFrame:
    """Read CSV bytes into a DataFrame with robust cleaning.

    - skipinitialspace to handle spaces after delimiters
    - strip column names
    - strip whitespace from string cells
    """
    df = pd.read_csv(BytesIO(content), skipinitialspace=True)
    df.columns = [str(c).strip() for c in df.columns]
    for col in df.select_dtypes(include=[object]).columns:
        df[col] = df[col].astype(str).str.strip()
    return df


if __name__ == '__main__':
    path = r"e:\applications\cattleapp\sample.csv"
    with open(path, 'rb') as f:
        content = f.read()
    df = _read_csv_bytes(content)
    print('\n--- HEAD ---')
    print(df.head().to_string())
    print('\n--- DTYPES ---')
    print(df.dtypes.to_string())
