#!/usr/bin/env python3
"""
ports_risk_pipeline.py

Unified pipeline for:
1. Feature engineering of port/process data
2. Training a risk classification model (XGBoost)
3. Scoring new port data with risk predictions
"""

import pandas as pd
import numpy as np
import joblib
import ipaddress
import os
from pathlib import Path
from sklearn.model_selection import train_test_split
from sklearn.preprocessing import LabelEncoder
from xgboost import XGBClassifier
import argparse

# ------------------------------------------
# SECTION 1: Feature Engineering
# ------------------------------------------

COMMON_PORTS = {22, 23, 80, 443, 445, 135, 139, 3306, 3389, 8080}

def classify_ip(addr: str) -> str:
    """Classify IP address into localhost/private/public/other."""
    if not isinstance(addr, str) or addr.strip() == "":
        return "other"
    try:
        ip = ipaddress.ip_address(addr.split("%")[0])
        if ip.is_loopback:
            return "localhost"
        elif ip.is_private:
            return "private"
        else:
            return "public"
    except ValueError:
        return "other"


def basic_featurize(df: pd.DataFrame, label_encoder=None, fit_encoder=False):
    """Feature engineering for both training and scoring."""
    df = df.copy()

    # Ensure columns exist
    for col in ["Protocol", "LocalPort", "LocalAddress", "ProcessName"]:
        if col not in df.columns:
            raise ValueError(f"Missing column: {col}")

    # Clean and normalize
    df["Protocol"] = df["Protocol"].astype(str)
    df["LocalPort"] = pd.to_numeric(df["LocalPort"], errors="coerce").fillna(0)
    df["ProcessName"] = df["ProcessName"].astype(str)
    df["LocalAddress"] = df["LocalAddress"].astype(str)

    # Derived features
    df["IsTCP"] = (df["Protocol"].str.upper() == "TCP").astype(int)
    df["IsUDP"] = (df["Protocol"].str.upper() == "UDP").astype(int)
    df["IsLocalhost"] = df["LocalAddress"].str.contains("127.0.0.1|::1").astype(int)

    # Encode ProcessName
    if fit_encoder:
        label_encoder = LabelEncoder()
        df["ProcessEncoded"] = label_encoder.fit_transform(df["ProcessName"])
    else:
        df["ProcessEncoded"] = label_encoder.transform(df["ProcessName"])

    # Return both df and encoder
    features = df[["LocalPort", "IsTCP", "IsUDP", "IsLocalhost", "ProcessEncoded"]]
    return features, label_encoder


# ------------------------------------------
# SECTION 2: Model Training
# ------------------------------------------

def train_model(data_path="../output/Ports.csv", model_dir="models"):
    """Train XGBoost model to classify risky ports."""
    data_path = Path(data_path)
    print(f"[+] Loading {data_path} ...")
    df = pd.read_csv(data_path)

    # Feature engineering
    X, le = basic_featurize(df, fit_encoder=True)

    # Heuristic risk labeling
    risky_ports = {1, 7, 9, 21, 22, 23, 25, 53, 67, 68, 69, 80, 109, 110,
                   111, 389, 3306, 3389, 8080, 5900}
    y = df["LocalPort"].apply(lambda x: 1 if x in risky_ports else 0)
    print(f"[+] Generated {y.sum()} risky samples out of {len(y)} total")

    # Split
    X_train, X_test, y_train, y_test = train_test_split(
        X, y, test_size=0.2, random_state=42
    )

    # Train XGBoost
    print("[+] Training XGBoost model ...")
    model = XGBClassifier(
        objective="binary:logistic",
        eval_metric="logloss",
        n_estimators=100,
        learning_rate=0.1,
        max_depth=5,
        subsample=0.8,
        colsample_bytree=0.8,
        use_label_encoder=False,
        random_state=42,
    )
    model.fit(X_train, y_train)

    acc = model.score(X_test, y_test)
    print(f"[+] Model trained! Test accuracy: {acc*100:.2f}%")

    # Save model + encoder
    os.makedirs(model_dir, exist_ok=True)
    joblib.dump(model, f"{model_dir}/ports_xgb.model")
    joblib.dump(le, f"{model_dir}/ports_label_encoder.pkl")
    print(f"[+] Saved model and encoder to {model_dir}/")

# ------------------------------------------
# SECTION 3: Scoring / Inference
# ------------------------------------------

def score_data(
    data_path="../output/Ports.csv",
    model_dir="models",
    output_path="../output/Ports_with_risk.csv"
):
    """Score port data using a trained model."""
    data_path = Path(data_path)
    model_path = Path(model_dir) / "ports_xgb.model"
    encoder_path = Path(model_dir) / "ports_label_encoder.pkl"

    print(f"[+] Loading model from {model_path}")
    model = joblib.load(model_path)
    label_encoder = joblib.load(encoder_path)

    print(f"[+] Reading {data_path}")
    df = pd.read_csv(data_path)

    print("[+] Engineering features ...")
    X, _ = basic_featurize(df, label_encoder=label_encoder, fit_encoder=False)

    print("[+] Predicting risk scores ...")
    risk_scores = model.predict_proba(X)[:, 1]
    df["RiskScore"] = (risk_scores * 100).round(2)

    Path(output_path).parent.mkdir(parents=True, exist_ok=True)
    df.to_csv(output_path, index=False)

    print(f"[+] Saved scored results to {output_path}")
    print(df[["Protocol", "LocalAddress", "LocalPort", "ProcessName", "RiskScore"]].head(15))


# ------------------------------------------
# SECTION 4: Command-line Interface
# ------------------------------------------

def main():
    parser = argparse.ArgumentParser(description="Port Risk Scoring Pipeline")
    parser.add_argument(
        "mode",
        choices=["train", "score"],
        help="Choose whether to train a model or score new data"
    )
    parser.add_argument("--data", default="../output/Ports.csv", help="Path to Ports.csv")
    parser.add_argument("--model_dir", default="models", help="Directory for model and encoder")
    parser.add_argument("--output", default="../output/Ports_with_risk.csv", help="Path to save scored CSV")
    args = parser.parse_args()

    if args.mode == "train":
        train_model(data_path=args.data, model_dir=args.model_dir)
    elif args.mode == "score":
        score_data(data_path=args.data, model_dir=args.model_dir, output_path=args.output)


if __name__ == "__main__":
    main()
