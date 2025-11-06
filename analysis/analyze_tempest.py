import pandas as pd
import json
import sys
import matplotlib.pyplot as plt
import io
import base64
from datetime import datetime

# ============ CONFIG ============
RISK_FACTORS = {
    "open_ports": 10,
    "autostart_entries": 2,
    "unsigned_drivers": 5,
    "disabled_firewall": 20,
    "unknown_services": 5
}


def calculate_risk(df):
    """Compute a simple risk score from enumeration data."""
    score = 0
    notes = []

    # 1. Open ports
    if "Category" in df.columns:
        ports = df[df["Category"] == "Ports"]
        if len(ports) > 0:
            score += len(ports) * RISK_FACTORS["open_ports"]
            notes.append(f"{len(ports)} open ports detected")

        # 2. Autostart
        auto = df[df["Category"] == "Autostart"]
        if len(auto) > 0:
            score += len(auto) * RISK_FACTORS["autostart_entries"]
            notes.append(f"{len(auto)} autostart entries found")

        # 3. Unsigned drivers
        drivers = df[df["Category"] == "Drivers"]
        unsigned = drivers[drivers["Path"].astype(str).str.contains("sys", case=False, na=False)]
        score += len(unsigned) * RISK_FACTORS["unsigned_drivers"]
        notes.append(f"{len(unsigned)} drivers analyzed")

        # 4. Firewall disabled (only if Enabled column exists)
        fw = df[df["Category"] == "FirewallRules"]
        if "Enabled" in fw.columns:
            disabled_fw = fw[fw["Enabled"].astype(str).str.lower().eq("false")]
            if len(disabled_fw) > 0:
                score += len(disabled_fw) * RISK_FACTORS["disabled_firewall"]
                notes.append(f"{len(disabled_fw)} disabled firewall rules")

    # Normalize score
    score = min(score, 100)
    if score < 30:
        risk = "Low"
    elif score < 70:
        risk = "Medium"
    else:
        risk = "High"

    return score, risk, notes


def generate_risk_chart(score, risk):
    """Generate a matplotlib gauge-like image for risk score."""
    fig, ax = plt.subplots(figsize=(6, 1))
    ax.barh(0, 100, color="#333", height=0.3)
    ax.barh(0, score, color={"Low": "#7ed957", "Medium": "#ffc107", "High": "#ff4d4d"}[risk], height=0.3)
    ax.set_xlim(0, 100)
    ax.set_yticks([])
    ax.set_xticks(range(0, 110, 10))
    ax.set_xlabel("Risk Score")
    ax.text(score + 2, 0, f"{score} ({risk})", color="white", va="center", fontsize=12, fontweight="bold")

    # ✅ Use rcParams instead of fig.patch to avoid Pylance warning
    plt.rcParams["figure.facecolor"] = "#0f111a"
    ax.set_facecolor("#0f111a")

    for spine in ["top", "right", "left"]:
        ax.spines[spine].set_visible(False)
    ax.spines["bottom"].set_color("#888")
    ax.tick_params(colors="#aaa")

    # Convert to base64 PNG
    buf = io.BytesIO()
    fig.savefig(buf, format="png", bbox_inches="tight", facecolor="#0f111a")
    buf.seek(0)
    encoded = base64.b64encode(buf.read()).decode("utf-8")
    plt.close(fig)
    return encoded

def build_dashboard(score, risk, notes, chart_b64, outfile):
    """Generate a simple visual HTML dashboard with embedded chart."""
    color = {"Low": "#7ed957", "Medium": "#ffc107", "High": "#ff4d4d"}[risk]
    html = f"""
    <html>
    <head>
    <title>T.E.M.P.E.S.T. Risk Dashboard</title>
    <style>
        body {{
            font-family: 'Segoe UI', sans-serif;
            background-color: #0f111a;
            color: #ddd;
            padding: 30px;
        }}
        .score {{
            font-size: 72px;
            font-weight: bold;
            color: {color};
        }}
        .risk {{
            font-size: 28px;
            color: {color};
            margin-bottom: 20px;
        }}
        ul {{
            background-color: #1e222e;
            padding: 15px;
            border-radius: 10px;
        }}
        li {{
            margin: 8px 0;
        }}
        img {{
            margin-top: 20px;
            border-radius: 10px;
            box-shadow: 0 0 10px #000;
        }}
    </style>
    </head>
    <body>
        <h1>🛰️ T.E.M.P.E.S.T. Risk Dashboard</h1>
        <p>Generated on {datetime.now().strftime("%Y-%m-%d %H:%M:%S")}</p>
        <div class="score">{score}</div>
        <div class="risk">Risk Level: {risk}</div>
        <img src="data:image/png;base64,{chart_b64}" alt="Risk Chart" width="600"/>
        <h2>Key Findings</h2>
        <ul>
            {''.join(f'<li>{n}</li>' for n in notes)}
        </ul>
    </body>
    </html>
    """
    with open(outfile, "w", encoding="utf-8") as f:
        f.write(html)


def main():
    if len(sys.argv) < 2:
        print("Usage: python analyze_tempest.py <csv_path>")
        sys.exit(1)

    csv_path = sys.argv[1]
    df = pd.read_csv(csv_path)

    score, risk, notes = calculate_risk(df)
    chart_b64 = generate_risk_chart(score, risk)

    # Save JSON
    report = {
        "timestamp": datetime.now().isoformat(),
        "risk_score": score,
        "risk_level": risk,
        "findings": notes
    }
    json_path = "./output/risk_report.json"
    with open(json_path, "w", encoding="utf-8") as f:
        json.dump(report, f, indent=2)

    # Save summary text
    with open("./output/summary.txt", "w", encoding="utf-8") as f:
        f.write(f"T.E.M.P.E.S.T. Summary Report\n")
        f.write(f"Generated: {datetime.now()}\n")
        f.write(f"Risk Score: {score}\n")
        f.write(f"Risk Level: {risk}\n")
        f.write("Findings:\n")
        for n in notes:
            f.write(f" - {n}\n")

    # Save HTML dashboard
    build_dashboard(score, risk, notes, chart_b64, "./output/risk_dashboard.html")

    print(f"[AI] Risk Score: {score} ({risk})")
    print("[AI] Reports generated:")
    print(" - risk_report.json")
    print(" - summary.txt")
    print(" - risk_dashboard.html")


if __name__ == "__main__":
    main()
