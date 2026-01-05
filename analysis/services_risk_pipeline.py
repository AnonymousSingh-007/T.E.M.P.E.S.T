#!/usr/bin/env python3
"""
services_risk_pipeline.py - Robust Services Risk Scoring Pipeline

- Handles missing columns
- Robust encoding for unseen categories
- XGBoost regression for risk scoring
- Safe output paths and clear logs
"""

import argparse
import pandas as pd
import numpy as np
import os
import joblib
from xgboost import XGBRegressor
from sklearn.preprocessing import OrdinalEncoder

# --------------------------
# Risk Calculation
# --------------------------
def compute_risk_label(df: pd.DataFrame) -> np.ndarray:
    """Compute heuristic risk label between 0–1."""
    risk = []

    # Safe column defaults
    for col in ["User", "PathName", "StartMode", "Description"]:
        if col not in df.columns:
            df[col] = ""

    for _, row in df.iterrows():
        score = 0.0

        user = str(row["User"]).lower()
        path = str(row["PathName"]).lower()
        start = str(row["StartMode"]).lower()
        desc = str(row["Description"]).lower()

        # User risk
        if any(sys in user for sys in ["localsystem", "localservice", "networkservice"]):
            score += 0.1
        elif user.strip() == "":
            score += 0.4
        else:
            score += 0.6

        # Path risk
        if "system32" in path or "windows\\" in path:
            score += 0.1
        elif "program files" in path:
            score += 0.3
        else:
            score += 0.7  # AppData, temp, custom folders

        # StartMode risk
        if start == "auto" and "system32" not in path:
            score += 0.5

        # Description risk
        if desc.strip() == "":
            score += 0.2

        # Normalize to 0–1
        risk.append(min(score / 2.0, 1.0))

    return np.array(risk, dtype=float)


# --------------------------
# Preprocessing
# --------------------------
def preprocess(df: pd.DataFrame, encoder: OrdinalEncoder = None, fit: bool = False):
    df = df.copy()
    str_cols = df.select_dtypes(include="object").columns.tolist()

    if encoder is None:
        encoder = OrdinalEncoder(handle_unknown="use_encoded_value", unknown_value=-1)

    if fit:
        df[str_cols] = encoder.fit_transform(df[str_cols])
    else:
        df[str_cols] = encoder.transform(df[str_cols])

    return df, encoder


# --------------------------
# Train Model
# --------------------------
def train_model(train_path: str, model_dir: str):
    if not os.path.exists(train_path):
        raise FileNotFoundError(f"Training CSV not found: {train_path}")

    df = pd.read_csv(train_path)
    print(f"[INFO] Loaded {len(df)} training services")

    # Compute heuristic labels
    df["label"] = compute_risk_label(df)

    df_proc, encoder = preprocess(df.drop(columns=["label"]), fit=True)
    y = df["label"]

    model = XGBRegressor(
        n_estimators=300,
        max_depth=6,
        learning_rate=0.1,
        objective="reg:squarederror",
        random_state=42
    )
    model.fit(df_proc, y)

    # Ensure model directory
    os.makedirs(model_dir, exist_ok=True)
    joblib.dump(model, os.path.join(model_dir, "services_xgb.model"))
    joblib.dump(encoder, os.path.join(model_dir, "encoder.pkl"))

    print(f"[OK] Trained XGBoost Services model → {model_dir}")


# --------------------------
# Score Model
# --------------------------
def score_model(csv_path: str, model_dir: str, output_path: str = None):
    if not os.path.exists(csv_path):
        raise FileNotFoundError(f"CSV not found: {csv_path}")

    if output_path is None:
        output_path = os.path.join(model_dir, "Services_with_risk.csv")
    os.makedirs(os.path.dirname(output_path), exist_ok=True)

    df = pd.read_csv(csv_path)

    model_path = os.path.join(model_dir, "services_xgb.model")
    encoder_path = os.path.join(model_dir, "encoder.pkl")

    if not os.path.exists(model_path) or not os.path.exists(encoder_path):
        raise FileNotFoundError("Model or encoder missing; train first")

    model = joblib.load(model_path)
    encoder = joblib.load(encoder_path)

    df_proc, _ = preprocess(df, encoder=encoder, fit=False)
    preds = model.predict(df_proc).clip(0, 1)

    df["RiskScore"] = np.round(preds * 100, 2)
    df.to_csv(output_path, index=False)

    print(f"[OK] Scored services → {output_path}")
    print(df[["User", "PathName", "StartMode", "Description", "RiskScore"]].head(15))


# --------------------------
# CLI
# --------------------------
def main():
    parser = argparse.ArgumentParser(description="Services ML Risk Pipeline")
    parser.add_argument("command", choices=["train", "score"], help="train or score")
    parser.add_argument("--data", required=True, help="CSV path")
    parser.add_argument("--model_dir", required=True, help="Directory for model and encoder")
    parser.add_argument("--output", help="Optional output CSV path")
    args = parser.parse_args()

    if args.command == "train":
        train_model(args.data, args.model_dir)
    elif args.command == "score":
        score_model(args.data, args.model_dir, output_path=args.output)


if __name__ == "__main__":
    main()
