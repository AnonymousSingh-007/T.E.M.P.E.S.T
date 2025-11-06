import pandas as pd
import json
import sys
import matplotlib.pyplot as plt
from datetime import datetime
import os

# =====================================
# CONFIGURATION
# =====================================
RISK_FACTORS = {
    "open_ports": 10,
    "autostart_entries": 2,
    "unsigned_drivers": 5,
    "disabled_firewall": 20,
    "unknown_services": 5
}

# Known system-safe autostart locations
SYSTEM_AUTOSTART_PATHS = [
    r"C:\Windows",
    r"C:\Program Files",
    r"C:\Program Files (x86)"
]

# Known safe drivers prefixes
SAFE_DRIVER_PREFIXES = [
    "C:\\Windows\\System32\\drivers",
    "C:\\Windows\\System32\\DriverStore"
]


# =====================================
# RISK CALCULATION
# =====================================
def calculate_risk(df):
    """Heuristic, context-aware risk scoring."""

    score = 0
    notes = []

    # -------------------------------
    # PORT ANALYSIS
    # -------------------------------
    ports = df[df['Category'] == 'Ports']
    if not ports.empty:
        tcp_ports = pd.DataFrame()
        udp_ports = pd.DataFrame()

        if 'Protocol' in ports.columns:
            proto_series = ports['Protocol'].astype(str).str.upper()
            tcp_ports = ports[proto_series == 'TCP']
            udp_ports = ports[proto_series == 'UDP']

        # Add weighting for specific high-risk ports
        high_risk_ports = [22, 23, 3306, 3389, 5900, 8080]
        if 'LocalPort' in ports.columns:
            risky = ports[ports['LocalPort'].isin(high_risk_ports)]
            score += len(risky) * 3  # weight high-risk ports more
            if not risky.empty:
                notes.append(f"High-risk ports found: {', '.join(map(str, risky['LocalPort'].unique()))}")

        score += len(ports) * RISK_FACTORS["open_ports"]
        notes.append(f"{len(ports)} open ports detected")

    # -------------------------------
    # AUTOSTART ANALYSIS
    # -------------------------------
    auto = df[df['Category'] == 'Autostart']
    if not auto.empty:
        score += len(auto) * RISK_FACTORS["autostart_entries"]
        suspicious_autostarts = []
        if 'Path' in auto.columns:
            for _, row in auto.iterrows():
                path = str(row['Path'])
                if not any(path.startswith(p) for p in SYSTEM_AUTOSTART_PATHS):
                    suspicious_autostarts.append(path)
                    score += 3
        if suspicious_autostarts:
            notes.append(f"{len(suspicious_autostarts)} suspicious autostart entries (non-system).")

    # -------------------------------
    # DRIVER ANALYSIS
    # -------------------------------
    drivers = df[df['Category'] == 'Drivers']
    if not drivers.empty:
        unsigned_count = 0
        weak_drivers = []
        if 'Path' in drivers.columns:
            for _, row in drivers.iterrows():
                path = str(row['Path'])
                if not any(path.startswith(p) for p in SAFE_DRIVER_PREFIXES):
                    weak_drivers.append(path)
                    unsigned_count += 1
                    score += RISK_FACTORS["unsigned_drivers"]
        notes.append(f"{unsigned_count} unsigned/3rd-party drivers found")

    # -------------------------------
    # FIREWALL ANALYSIS
    # -------------------------------
    fw = df[df['Category'] == 'FirewallRules']
    if not fw.empty and 'Enabled' in fw.columns:
        disabled_fw = fw[fw['Enabled'].astype(str).str.lower().eq("false")]
        if len(disabled_fw) > 0:
            score += len(disabled_fw) * RISK_FACTORS["disabled_firewall"]
            notes.append(f"{len(disabled_fw)} disabled firewall rules detected")

    # -------------------------------
    # SERVICE ANALYSIS
    # -------------------------------
    services = df[df['Category'] == 'Services']
    if not services.empty:
        unknown_services = []
        if 'Path' in services.columns:
            for _, row in services.iterrows():
                path = str(row['Path'])
                if path and not path.lower().startswith("c:\\windows"):
                    unknown_services.append(path)
                    score += RISK_FACTORS["unknown_services"]
        if unknown_services:
            notes.append(f"{len(unknown_services)} non-system services detected")

    # -------------------------------
    # FINAL RISK NORMALIZATION
    # -------------------------------
    if score <= 30:
        risk = "Low"
    elif score <= 70:
        risk = "Medium"
    else:
        risk = "High"

    score = min(score, 100)
    return score, risk, notes


# =====================================
# HTML + PLOT REPORT GENERATION
# =====================================
def build_dashboard(score, risk, notes, outfile):
    """Generate visual HTML dashboard + PNG chart."""
    color_map = {"Low": "#7ed957", "Medium": "#ffc107", "High": "#ff4d4d"}
    color = color_map.get(risk, "#cccccc")

    # --- Create Matplotlib chart ---
    fig, ax = plt.subplots(figsize=(6, 1))
    ax.barh(["Risk Score"], [score], color=color)
    ax.set_xlim(0, 100)
    ax.set_xlabel("0 (Low) ←→ 100 (High)")
    ax.set_title(f"Risk Level: {risk}")
    fig.tight_layout()

    chart_path = "./output/risk_chart.png"
    fig.savefig(chart_path)
    plt.close(fig)

    # --- Build HTML report ---
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
            width: 80%;
            border-radius: 8px;
            margin-top: 20px;
        }}
    </style>
    </head>
    <body>
        <h1>🛰️ T.E.M.P.E.S.T. Risk Dashboard</h1>
        <p>Generated on {datetime.now().strftime("%Y-%m-%d %H:%M:%S")}</p>
        <div class="score">{score}</div>
        <div class="risk">Risk Level: {risk}</div>
        <img src="risk_chart.png" alt="Risk Chart">
        <h2>Key Findings</h2>
        <ul>
            {''.join(f'<li>{n}</li>' for n in notes)}
        </ul>
    </body>
    </html>
    """

    with open(outfile, "w", encoding="utf-8") as f:
        f.write(html)


# =====================================
# MAIN ENTRY POINT
# =====================================
def main():
    if len(sys.argv) < 2:
        print("Usage: python analyze_tempest.py <csv_path>")
        sys.exit(1)

    csv_path = sys.argv[1]
    if not os.path.exists(csv_path):
        print(f"[ERROR] File not found: {csv_path}")
        sys.exit(1)

    df = pd.read_csv(csv_path)

    # Calculate heuristic risk
    score, risk, notes = calculate_risk(df)

    # Save JSON report
    report = {
        "timestamp": datetime.now().isoformat(),
        "risk_score": score,
        "risk_level": risk,
        "findings": notes
    }

    os.makedirs("./output", exist_ok=True)
    json_path = "./output/risk_report.json"
    with open(json_path, "w", encoding="utf-8") as f:
        json.dump(report, f, indent=2)

    # Save text summary
    with open("./output/summary.txt", "w", encoding="utf-8") as f:
        f.write("T.E.M.P.E.S.T. Summary Report\n")
        f.write(f"Generated: {datetime.now()}\n")
        f.write(f"Risk Score: {score}\n")
        f.write(f"Risk Level: {risk}\n\nFindings:\n")
        for n in notes:
            f.write(f" - {n}\n")

    # Generate HTML dashboard
    build_dashboard(score, risk, notes, "./output/risk_dashboard.html")

    print(f"[AI] Risk Score: {score} ({risk})")
    print("[AI] Reports generated:")
    print(" - risk_report.json")
    print(" - summary.txt")
    print(" - risk_dashboard.html")
    print(" - risk_chart.png")


if __name__ == "__main__":
    main()
