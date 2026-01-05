#!/usr/bin/env python3
"""
ports_risk_pipeline.py - Robust Port Risk Scoring Pipeline

- Safe feature engineering
- Handles unseen process names
- DummyClassifier fallback if training labels degenerate
- Clear logging
"""

import pandas as pd
import numpy as np
import joblib
import os
import ipaddress
from pathlib import Path
from sklearn.model_selection import train_test_split
from sklearn.preprocessing import LabelEncoder
from sklearn.dummy import DummyClassifier
from xgboost import XGBClassifier
import argparse
import warnings

COMMON_PORTS = {22, 23, 80, 443, 445, 135, 139, 3306, 3389, 8080}
UNKNOWN_TOKEN = "__UNKNOWN__"


# --------------------------
# Utilities
# --------------------------
def ensure_dir(p: Path):
    p.mkdir(parents=True, exist_ok=True)
    return p


def classify_ip(addr: str) -> str:
    try:
        ip = ipaddress.ip_address(addr.split("%")[0])
        if ip.is_loopback:
            return "localhost"
        elif ip.is_private:
            return "private"
        else:
            return "public"
    except Exception:
        return "other"


def safe_label_fit(series: pd.Series) -> LabelEncoder:
    le = LabelEncoder()
    vals = series.fillna("").astype(str).tolist()
    vals.append(UNKNOWN_TOKEN)
    le.fit(vals)
    return le


def safe_label_transform(label_encoder: LabelEncoder, series: pd.Series) -> np.ndarray:
    vals = series.fillna("").astype(str).tolist()
    classes = list(label_encoder.classes_)
    if UNKNOWN_TOKEN not in classes:
        classes.append(UNKNOWN_TOKEN)
        label_encoder.classes_ = np.array(classes)
    mapped = [v if v in label_encoder.classes_ else UNKNOWN_TOKEN for v in vals]
    return label_encoder.transform(mapped)


# --------------------------
# Feature Engineering
# --------------------------
def basic_featurize(df: pd.DataFrame, label_encoder: LabelEncoder = None, fit_encoder: bool = False):
    df = df.copy()

    # Safe default columns
    for col in ["Protocol", "LocalPort", "LocalAddress", "ProcessName"]:
        if col not in df.columns:
            df[col] = "" if col != "LocalPort" else 0

    df["Protocol"] = df["Protocol"].astype(str).fillna("")
    df["LocalPort"] = pd.to_numeric(df["LocalPort"], errors="coerce").fillna(0).astype(int)
    df["ProcessName"] = df["ProcessName"].astype(str).fillna("")
    df["LocalAddress"] = df["LocalAddress"].astype(str).fillna("")

    df["IsTCP"] = (df["Protocol"].str.upper() == "TCP").astype(int)
    df["IsUDP"] = (df["Protocol"].str.upper() == "UDP").astype(int)
    df["IsLocalhost"] = df["LocalAddress"].str.contains("127.0.0.1|::1").astype(int)
    df["IsCommonPort"] = df["LocalPort"].apply(lambda p: 1 if int(p) in COMMON_PORTS else 0)

    if fit_encoder:
        le = safe_label_fit(df["ProcessName"])
        df["ProcessEncoded"] = le.transform(df["ProcessName"])
        return df[["LocalPort", "IsTCP", "IsUDP", "IsLocalhost", "IsCommonPort", "ProcessEncoded"]], le
    else:
        if label_encoder is None:
            raise ValueError("label_encoder must be provided when fit_encoder=False")
        df["ProcessEncoded"] = safe_label_transform(label_encoder, df["ProcessName"])
        return df[["LocalPort", "IsTCP", "IsUDP", "IsLocalhost", "IsCommonPort", "ProcessEncoded"]], label_encoder


# --------------------------
# Train Model
# --------------------------
def train_model(data_path="../output/Ports.csv", model_dir="models"):
    data_path = Path(data_path)
    model_dir = ensure_dir(Path(model_dir))

    if not data_path.exists():
        raise FileNotFoundError(f"Training CSV not found: {data_path}")

    df = pd.read_csv(data_path)
    X, le = basic_featurize(df, fit_encoder=True)

    risky_ports = {1, 7, 9, 21, 22, 23, 25, 53, 67, 68, 69, 80, 109, 110,
                   111, 389, 3306, 3389, 8080, 5900}

    y = df["LocalPort"].apply(lambda x: 1 if int(x) in risky_ports else 0).astype(int)

    if y.nunique() > 1:
        stratify = y
    else:
        stratify = None

    X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=0.2, random_state=42, stratify=stratify)

    # Fallback DummyClassifier if degenerate
    if y_train.nunique() < 2:
        warnings.warn("[!] Only one class in training labels; using DummyClassifier fallback.")
        model = DummyClassifier(strategy="most_frequent")
        model.fit(X_train, y_train)
    else:
        model = XGBClassifier(
            objective="binary:logistic",
            eval_metric="logloss",
            n_estimators=100,
            learning_rate=0.1,
            max_depth=5,
            subsample=0.8,
            colsample_bytree=0.8,
            use_label_encoder=False,
            random_state=42
        )
        model.fit(X_train, y_train)

    # Save
    joblib.dump(model, model_dir / "ports_xgb.model")
    joblib.dump(le, model_dir / "ports_label_encoder.pkl")
    print(f"[OK] Model and encoder saved in {model_dir}")


# --------------------------
# Score Data
# --------------------------
def score_data(data_path="../output/Ports.csv", model_dir="models", output_path="../output/Ports_with_risk.csv"):
    data_path = Path(data_path)
    model_dir = Path(model_dir)
    output_path = Path(output_path)
    output_path.parent.mkdir(parents=True, exist_ok=True)

    model_path = model_dir / "ports_xgb.model"
    encoder_path = model_dir / "ports_label_encoder.pkl"

    if not model_path.exists() or not encoder_path.exists():
        raise FileNotFoundError("Model or encoder missing; train first.")

    model = joblib.load(model_path)
    le = joblib.load(encoder_path)

    df = pd.read_csv(data_path)
    X, _ = basic_featurize(df, label_encoder=le, fit_encoder=False)

    # Predict
    if hasattr(model, "predict_proba"):
        risk_scores = model.predict_proba(X)[:, 1]
    else:
        pred = model.predict(X)
        risk_scores = np.array(pred, dtype=float)

    df["RiskScore"] = (risk_scores * 100).round(2)
    df.to_csv(output_path, index=False)

    print(f"[OK] Scored data saved to {output_path}")
    print(df[["Protocol", "LocalAddress", "LocalPort", "ProcessName", "RiskScore"]].head(15))


# --------------------------
# CLI
# --------------------------
def main():
    parser = argparse.ArgumentParser(description="Ports ML Risk Pipeline")
    parser.add_argument("mode", choices=["train", "score"], help="train or score")
    parser.add_argument("--data", default="../output/Ports.csv")
    parser.add_argument("--model_dir", default="models")
    parser.add_argument("--output", default="../output/Ports_with_risk.csv")
    args = parser.parse_args()

    if args.mode == "train":
        train_model(data_path=args.data, model_dir=args.model_dir)
    elif args.mode == "score":
        score_data(data_path=args.data, model_dir=args.model_dir, output_path=args.output)


if __name__ == "__main__":
    main()
