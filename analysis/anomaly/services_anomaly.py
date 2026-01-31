#!/usr/bin/env python3
"""
services_anomaly.py
Unsupervised anomaly detection for Windows services
"""

import argparse
from pathlib import Path
import pandas as pd
import numpy as np
from sklearn.ensemble import IsolationForest

SUSPICIOUS_PATH_KEYWORDS = [
    "\\users\\",
    "\\temp\\",
    "\\appdata\\",
    "\\downloads\\"
]

# -----------------------------
# Feature Engineering
# -----------------------------
def featurize(df: pd.DataFrame) -> pd.DataFrame:
    df = df.copy()

    for col in ["Name", "Status", "StartMode", "PathName", "User", "ServiceType"]:
        if col not in df.columns:
            df[col] = ""

    df = df.fillna("")

    df["IsRunning"] = (df["Status"].str.lower() == "running").astype(int)
    df["IsAutoStart"] = (df["StartMode"].str.lower() == "auto").astype(int)

    df["IsSystemAccount"] = df["User"].str.contains(
        r"localservice|networkservice|localsystem",
        case=False,
        regex=True
    ).astype(int)

    df["SuspiciousPath"] = df["PathName"].str.lower().apply(
        lambda p: 1 if any(k in p for k in SUSPICIOUS_PATH_KEYWORDS) else 0
    )

    # Microsoft services are common & benign
    df["IsMicrosoft"] = df["PathName"].str.contains(
        r"windows\\system32|microsoft",
        case=False,
        regex=True
    ).astype(int)

    # Service rarity (strong signal)
    freq = df["Name"].value_counts()
    df["ServiceRarity"] = 1 / df["Name"].map(freq).fillna(1)

    return df[
        [
            "IsRunning",
            "IsAutoStart",
            "IsSystemAccount",
            "SuspiciousPath",
            "IsMicrosoft",
            "ServiceRarity",
        ]
    ]


# -----------------------------
# Anomaly Detection
# -----------------------------
def score_services(input_csv: Path, output_csv: Path):
    df = pd.read_csv(input_csv)

    if df.empty:
        df["AnomalyScore"] = []
        df["AnomalyLevel"] = []
        df.to_csv(output_csv, index=False)
        return

    X = featurize(df)

    model = IsolationForest(
        n_estimators=200,
        contamination=0.07,
        random_state=42
    )

    model.fit(X)

    scores = 1 - model.decision_function(X)

    scores = (scores - scores.min()) / (scores.max() - scores.min() + 1e-6)

    df["AnomalyScore"] = (scores * 100).round(2)

    def level(s):
        if s >= 85:
            return "CRITICAL"
        elif s >= 65:
            return "HIGH"
        elif s >= 40:
            return "MEDIUM"
        else:
            return "LOW"

    df["AnomalyLevel"] = df["AnomalyScore"].apply(level)

    output_csv.parent.mkdir(parents=True, exist_ok=True)
    df.to_csv(output_csv, index=False)


# -----------------------------
# CLI
# -----------------------------
def main():
    parser = argparse.ArgumentParser(description="Services anomaly detection")
    parser.add_argument("--input", required=True)
    parser.add_argument("--output", required=True)
    args = parser.parse_args()

    score_services(Path(args.input), Path(args.output))


if __name__ == "__main__":
    main()
