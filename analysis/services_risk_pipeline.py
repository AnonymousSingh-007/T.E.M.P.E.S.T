import argparse
import pandas as pd
import os
import joblib
from xgboost import XGBRegressor
from sklearn.preprocessing import OrdinalEncoder

# --------------------------
# Synthetic Risk Labeling
# --------------------------

def compute_risk_label(df):
    risk = []

    for _, row in df.iterrows():
        score = 0.0

        user = str(row.get("User", "")).lower()
        path = str(row.get("PathName", "")).lower()
        start = str(row.get("StartMode", "")).lower()
        desc = str(row.get("Description", "")).lower()

        # ---- USER RISK ----
        if any(sys in user for sys in ["localsystem", "localservice", "networkservice"]):
            score += 0.1
        elif user.strip() == "":
            score += 0.4
        else:
            score += 0.6

        # ---- PATH RISK ----
        if "system32" in path or "windows\\" in path:
            score += 0.1
        elif "program files" in path:
            score += 0.3
        else:
            score += 0.7  # AppData, temp, custom folders

        # ---- STARTMODE ----
        if start == "auto" and "system32" not in path:
            score += 0.5

        # ---- DESCRIPTION ----
        if desc.strip() == "":
            score += 0.2

        # normalize into 0–1
        risk.append(min(score / 2.0, 1.0))

    return risk

# --------------------------
# Preprocessing
# --------------------------

def preprocess(df, encoder=None, fit=False):
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
# Training
# --------------------------

def train_model(train_path, model_dir):
    df = pd.read_csv(train_path)

    print(f"[INFO] Loaded {len(df)} training services")

    df["label"] = compute_risk_label(df)

    df_proc, encoder = preprocess(df.drop(columns=["label"]), fit=True)
    y = df["label"]

    model = XGBRegressor(
        n_estimators=300,
        max_depth=6,
        learning_rate=0.1,
        objective="reg:squarederror"
    )

    model.fit(df_proc, y)

    os.makedirs(model_dir, exist_ok=True)
    joblib.dump(model, os.path.join(model_dir, "services_xgb.model"))
    joblib.dump(encoder, os.path.join(model_dir, "encoder.pkl"))

    print("[OK] Trained XGBoost Services model")

# --------------------------
# Scoring
# --------------------------

def score_model(csv_path, model_dir):
    df = pd.read_csv(csv_path)

    model = joblib.load(os.path.join(model_dir, "services_xgb.model"))
    encoder = joblib.load(os.path.join(model_dir, "encoder.pkl"))

    df_proc, _ = preprocess(df, encoder=encoder, fit=False)

    preds = model.predict(df_proc)
    preds = preds.clip(0,1)

    df["risk_score"] = preds

    out_path = os.path.join(model_dir, "Services_with_risk.csv")
    df.to_csv(out_path, index=False)

    print(f"[OK] Scored services → {out_path}")

# --------------------------
# Main
# --------------------------

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--data", required=True)
    parser.add_argument("--model_dir", required=True)
    parser.add_argument("command", choices=["train", "score"])
    args = parser.parse_args()

    if args.command == "train":
        train_model(args.data, args.model_dir)

    elif args.command == "score":
        score_model(args.data, args.model_dir)

if __name__ == "__main__":
    main()
