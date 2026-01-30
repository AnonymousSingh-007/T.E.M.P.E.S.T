#!/usr/bin/env python3
"""
ports_anomaly.py
Unsupervised anomaly detection for listening ports using Isolation Forest
"""

import argparse
from pathlib import Path
import pandas as pd
import numpy as np
from sklearn.ensemble import IsolationForest

COMMON_PORTS = {
    20, 21, 22, 23, 25, 53, 67, 68,
    80, 110, 123, 135, 139, 143,
    443, 445, 3389
}

# -----------------------------
# Feature Engineering
# -----------------------------
def featurize(df: pd.DataFrame) -> pd.DataFrame:
    df = df.copy()

    for col in ["Protocol", "LocalAddress", "LocalPort", "ProcessName"]:
        if col not in df.columns:
            df[col] = ""

    df["LocalPort"] = pd.to_numeric(df["LocalPort"], errors="coerce").fillna(0).astype(int)
    df["Protocol"] = df["Protocol"].astype(str)
    df["LocalAddress"] = df["LocalAddress"].astype(str)
    df["ProcessName"] = df["ProcessName"].astype(str)

    df["IsTCP"] = (df["Protocol"].str.upper() == "TCP").astype(int)
    df["IsUDP"] = (df["Protocol"].str.upper() == "UDP").astype(int)

    df["IsCommonPort"] = df["LocalPort"].apply(lambda p: 1 if p in COMMON_PORTS else 0)
    df["IsLocalhost"] = df["LocalAddress"].str.contains(r"127\.0\.0\.1|::1", regex=True).astype(int)

    # Process rarity = strong malware signal
    freq = df["ProcessName"].value_counts()
    df["ProcessRarity"] = 1 / df["ProcessName"].map(freq).fillna(1)

    return df[
        [
            "LocalPort",
            "IsTCP",
            "IsUDP",
            "IsCommonPort",
            "IsLocalhost",
            "ProcessRarity",
        ]
    ]


# -----------------------------
# Anomaly Detection
# -----------------------------
def score_ports(input_csv: Path, output_csv: Path):
    df = pd.read_csv(input_csv)

    if df.empty:
        df["AnomalyScore"] = []
        df["AnomalyLevel"] = []
        df.to_csv(output_csv, index=False)
        return

    X = featurize(df)

    model = IsolationForest(
        n_estimators=200,
        contamination=0.08,
        random_state=42,
    )

    model.fit(X)

    raw_scores = model.decision_function(X)
    anomaly_scores = 1 - raw_scores

    # Normalize 0–100
    anomaly_scores = (anomaly_scores - anomaly_scores.min()) / (
        anomaly_scores.max() - anomaly_scores.min() + 1e-6
    )

    df["AnomalyScore"] = (anomaly_scores * 100).round(2)

    def level(score):
        if score >= 85:
            return "CRITICAL"
        elif score >= 65:
            return "HIGH"
        elif score >= 40:
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
    parser = argparse.ArgumentParser(description="Ports anomaly detection")
    parser.add_argument("--input", required=True, help="Ports.csv path")
    parser.add_argument("--output", required=True, help="Output CSV path")
    args = parser.parse_args()

    score_ports(Path(args.input), Path(args.output))


if __name__ == "__main__":
    main()
