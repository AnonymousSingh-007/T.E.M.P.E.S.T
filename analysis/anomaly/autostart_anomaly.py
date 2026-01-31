#!/usr/bin/env python3
"""
autostart_anomaly.py
Unsupervised anomaly detection for startup persistence
"""

import argparse
from pathlib import Path
import pandas as pd
import numpy as np
from sklearn.ensemble import IsolationForest

SCRIPT_EXTENSIONS = [".ps1", ".vbs", ".js", ".bat", ".cmd"]

USER_PATH_KEYWORDS = [
    "\\users\\",
    "\\appdata\\",
    "\\temp\\"
]

# -----------------------------
# Feature Engineering
# -----------------------------
def featurize(df: pd.DataFrame) -> pd.DataFrame:
    df = df.copy()

    for col in ["Name", "Command", "Location", "User", "Source"]:
        if col not in df.columns:
            df[col] = ""

    df = df.fillna("")

    df["IsUserContext"] = (~df["User"].str.contains(
        r"system|localsystem",
        case=False,
        regex=True
    )).astype(int)

    df["IsUserPath"] = df["Command"].str.lower().apply(
        lambda c: 1 if any(k in c for k in USER_PATH_KEYWORDS) else 0
    )

    df["IsScript"] = df["Command"].str.lower().apply(
        lambda c: 1 if any(c.strip().endswith(ext) for ext in SCRIPT_EXTENSIONS) else 0
    )

    df["CommandLength"] = df["Command"].str.len()

    # Rarity = persistence trick
    freq = df["Command"].value_counts()
    df["CommandRarity"] = 1 / df["Command"].map(freq).fillna(1)

    return df[
        [
            "IsUserContext",
            "IsUserPath",
            "IsScript",
            "CommandLength",
            "CommandRarity",
        ]
    ]


# -----------------------------
# Anomaly Detection
# -----------------------------
def score_autostart(input_csv: Path, output_csv: Path):
    df = pd.read_csv(input_csv)

    if df.empty:
        df["AnomalyScore"] = []
        df["AnomalyLevel"] = []
        df.to_csv(output_csv, index=False)
        return

    X = featurize(df)

    model = IsolationForest(
        n_estimators=200,
        contamination=0.1,
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
    parser = argparse.ArgumentParser(description="Autostart anomaly detection")
    parser.add_argument("--input", required=True)
    parser.add_argument("--output", required=True)
    args = parser.parse_args()

    score_autostart(Path(args.input), Path(args.output))


if __name__ == "__main__":
    main()
