#!/usr/bin/env python3
"""
ports_risk_pipeline.py - robust version

Improvements over original:
- Handles unseen process names at scoring time by mapping them to a stable "__UNKNOWN__" token.
- Saves both model and label encoder artifacts reliably.
- If dataset is degenerate (no positive class), trains a fallback DummyClassifier so scoring still works.
- Clearer logging and safe file checks.
"""

import pandas as pd
import numpy as np
import joblib
import ipaddress
import os
from pathlib import Path
from sklearn.model_selection import train_test_split
from sklearn.preprocessing import LabelEncoder
from sklearn.dummy import DummyClassifier
from xgboost import XGBClassifier
import argparse
import warnings

COMMON_PORTS = {22, 23, 80, 443, 445, 135, 139, 3306, 3389, 8080}
UNKNOWN_TOKEN = "__UNKNOWN__"

# ---------- Utilities ----------

def ensure_dir(p: Path):
    p = Path(p)
    p.mkdir(parents=True, exist_ok=True)
    return p

def classify_ip(addr: str) -> str:
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

def safe_label_fit(series: pd.Series) -> LabelEncoder:
    le = LabelEncoder()
    vals = series.fillna("").astype(str).tolist()
    # Ensure UNKNOWN_TOKEN is part of classes so scoring can safely map unseen labels.
    vals_with_unknown = vals + [UNKNOWN_TOKEN]
    le.fit(vals_with_unknown)
    return le

def safe_label_transform(label_encoder: LabelEncoder, series: pd.Series) -> np.ndarray:
    """
    Transform a series using label_encoder. Any unseen label is mapped to UNKNOWN_TOKEN.
    If UNKNOWN_TOKEN is not present in label_encoder.classes_, it is appended (in-place).
    """
    vals = series.fillna("").astype(str).tolist()
    classes = list(label_encoder.classes_)
    if UNKNOWN_TOKEN not in classes:
        classes.append(UNKNOWN_TOKEN)
        label_encoder.classes_ = np.array(classes)

    mapped = [v if v in label_encoder.classes_ else UNKNOWN_TOKEN for v in vals]
    return label_encoder.transform(mapped)

# ---------- Feature engineering ----------

def basic_featurize(df: pd.DataFrame, label_encoder: LabelEncoder = None, fit_encoder: bool = False):
    df = df.copy()
    # Ensure required columns
    for col in ["Protocol", "LocalPort", "LocalAddress", "ProcessName"]:
        if col not in df.columns:
            raise ValueError(f"Missing column: {col}")

    df["Protocol"] = df["Protocol"].astype(str).fillna("")
    df["LocalPort"] = pd.to_numeric(df["LocalPort"], errors="coerce").fillna(0).astype(int)
    df["ProcessName"] = df["ProcessName"].astype(str).fillna("")
    df["LocalAddress"] = df["LocalAddress"].astype(str).fillna("")

    df["IsTCP"] = (df["Protocol"].str.upper() == "TCP").astype(int)
    df["IsUDP"] = (df["Protocol"].str.upper() == "UDP").astype(int)
    df["IsLocalhost"] = df["LocalAddress"].str.contains("127.0.0.1|::1", regex=True).astype(int)
    df["IsCommonPort"] = df["LocalPort"].apply(lambda p: 1 if int(p) in COMMON_PORTS else 0)

    # Label encoding logic
    if fit_encoder:
        le = safe_label_fit(df["ProcessName"])
        df["ProcessEncoded"] = le.transform(df["ProcessName"].astype(str).tolist())
        return df[["LocalPort", "IsTCP", "IsUDP", "IsLocalhost", "IsCommonPort", "ProcessEncoded"]], le
    else:
        if label_encoder is None:
            raise ValueError("label_encoder must be provided when fit_encoder=False")
        df["ProcessEncoded"] = safe_label_transform(label_encoder, df["ProcessName"])
        return df[["LocalPort", "IsTCP", "IsUDP", "IsLocalhost", "IsCommonPort", "ProcessEncoded"]], label_encoder

# ---------- Model training ----------

def train_model(data_path="../output/Ports.csv", model_dir="models"):
    data_path = Path(data_path)
    print(f"[+] Loading {data_path} ...")
    df = pd.read_csv(data_path)
    X, le = basic_featurize(df, fit_encoder=True)

    risky_ports = {1, 7, 9, 21, 22, 23, 25, 53, 67, 68, 69, 80, 109, 110,
                   111, 389, 3306, 3389, 8080, 5900}
    y = df["LocalPort"].apply(lambda x: 1 if int(x) in risky_ports else 0).astype(int)
    print(f"[+] Generated {y.sum()} risky samples out of {len(y)} total")

    # Split
    X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=0.2, random_state=42, stratify=y if y.nunique() > 1 else None)

    model_dir = ensure_dir(Path(model_dir))

    # If labels contain only one class, fall back to DummyClassifier so we can still score later.
    if y_train.nunique() < 2:
        warnings.warn("[!] Training labels contain only one class. Using DummyClassifier fallback.")
        from sklearn.dummy import DummyClassifier
        model = DummyClassifier(strategy="most_frequent")
        model.fit(X_train, y_train)
    else:
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

    # Evaluate if possible
    if X_test.shape[0] > 0 and y_test.nunique() > 1:
        acc = model.score(X_test, y_test)
        print(f"[+] Model trained! Test accuracy: {acc*100:.2f}%")
    else:
        print("[+] Model trained (no reliable test set available to score).")

    # Save artifacts
    joblib.dump(model, Path(model_dir) / "ports_xgb.model")
    joblib.dump(le, Path(model_dir) / "ports_label_encoder.pkl")
    print(f"[+] Saved model and encoder to {model_dir}/")

# ---------- Scoring ----------

def score_data(data_path="../output/Ports.csv", model_dir="models", output_path="../output/Ports_with_risk.csv"):
    data_path = Path(data_path)
    model_path = Path(model_dir) / "ports_xgb.model"
    encoder_path = Path(model_dir) / "ports_label_encoder.pkl"

    if not model_path.exists() or not encoder_path.exists():
        raise FileNotFoundError("Model or encoder missing; run training first (train subcommand)")

    print(f"[+] Loading model from {model_path}")
    model = joblib.load(model_path)
    label_encoder = joblib.load(encoder_path)

    print(f"[+] Reading {data_path}")
    df = pd.read_csv(data_path)

    print("[+] Engineering features ...")
    X, _ = basic_featurize(df, label_encoder=label_encoder, fit_encoder=False)

    print("[+] Predicting risk scores ...")
    if hasattr(model, "predict_proba"):
        risk_scores = model.predict_proba(X)[:, 1]
    else:
        # fallback: some DummyClassifier variants have predict_proba but be safe
        try:
            pred = model.predict(X)
            # map predictions 0/1 to probabilities
            risk_scores = np.array(pred, dtype=float)
        except Exception:
            risk_scores = np.zeros(len(X), dtype=float)

    df["RiskScore"] = (risk_scores * 100).round(2)
    Path(output_path).parent.mkdir(parents=True, exist_ok=True)
    df.to_csv(output_path, index=False)
    print(f"[+] Saved scored results to {output_path}")
    print(df[["Protocol", "LocalAddress", "LocalPort", "ProcessName", "RiskScore"]].head(15))

# ---------- CLI ----------

def main():
    parser = argparse.ArgumentParser(description="Port Risk Scoring Pipeline (robust)")
    parser.add_argument("mode", choices=["train", "score"], help="train or score")
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
