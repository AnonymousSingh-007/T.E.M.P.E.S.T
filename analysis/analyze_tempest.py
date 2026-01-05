#!/usr/bin/env python3
"""
analyze_tempest.py - Heuristic Risk Scoring & Dashboard
"""

import pandas as pd
import json
import sys
import matplotlib.pyplot as plt
from datetime import datetime
from pathlib import Path

# --------------------------
# CONFIGURATION
# --------------------------
RISK_FACTORS = {
    "open_ports": 10,
    "autostart_entries": 2,
    "unsigned_drivers": 5,
    "disabled_firewall": 20,
    "unknown_services": 5
}

SYSTEM_AUTOSTART_PATHS = [
    r"C:\Windows",
    r"C:\Program Files",
    r"C:\Program Files (x86)"
]

SAFE_DRIVER_PREFIXES = [
    r"C:\Windows\System32\drivers",
    r"C:\Windows\System32\DriverStore"
]


# --------------------------
# RISK CALCULATION
# --------------------------
def calculate_risk(df: pd.DataFrame):
    score = 0
    notes = []

    # PORTS
    ports = df[df.get('Category') == 'Ports'] if 'Category' in df.columns else pd.DataFrame()
    if not ports.empty:
        if 'LocalPort' in ports.columns:
            high_risk_ports = [22, 23, 3306, 3389, 5900, 8080]
            risky = ports[ports['LocalPort'].isin(high_risk_ports)]
            score += len(risky) * 3
            if not risky.empty:
                notes.append(f"High-risk ports: {', '.join(map(str, risky['LocalPort'].unique()))}")

        score += len(ports) * RISK_FACTORS["open_ports"]
        notes.append(f"{len(ports)} open ports detected")

    # AUTOSTART
    auto = df[df.get('Category') == 'Autostart'] if 'Category' in df.columns else pd.DataFrame()
    if not auto.empty:
        score += len(auto) * RISK_FACTORS["autostart_entries"]
        suspicious = []
        for p in auto.get('Path', []):
            if not any(p.startswith(s) for s in SYSTEM_AUTOSTART_PATHS):
                suspicious.append(p)
                score += 3
        if suspicious:
            notes.append(f"{len(suspicious)} suspicious autostart entries")

    # DRIVERS
    drivers = df[df.get('Category') == 'Drivers'] if 'Category' in df.columns else pd.DataFrame()
    if not drivers.empty:
        unsigned = []
        for p in drivers.get('Path', []):
            if not any(p.startswith(s) for s in SAFE_DRIVER_PREFIXES):
                unsigned.append(p)
                score += RISK_FACTORS["unsigned_drivers"]
        if unsigned:
            notes.append(f"{len(unsigned)} unsigned/3rd-party drivers found")

    # FIREWALL
    fw = df[df.get('Category') == 'FirewallRules'] if 'Category' in df.columns else pd.DataFrame()
    if not fw.empty and 'Enabled' in fw.columns:
        disabled = fw[fw['Enabled'].astype(str).str.lower() == "false"]
        score += len(disabled) * RISK_FACTORS["disabled_firewall"]
        if len(disabled) > 0:
            notes.append(f"{len(disabled)} disabled firewall rules")

    # SERVICES
    services = df[df.get('Category') == 'Services'] if 'Category' in df.columns else pd.DataFrame()
    if not services.empty:
        unknown = []
        for p in services.get('Path', []):
            if p and not str(p).lower().startswith("c:\\windows"):
                unknown.append(p)
                score += RISK_FACTORS["unknown_services"]
        if unknown:
            notes.append(f"{len(unknown)} non-system services detected")

    # Normalize risk
    score = min(score, 100)
    if score <= 30:
        risk = "Low"
    elif score <= 70:
        risk = "Medium"
    else:
        risk = "High"

    return score, risk, notes


# --------------------------
# HTML + PLOT DASHBOARD
# --------------------------
def build_dashboard(score, risk, notes, out_dir: str):
    out_dir = Path(out_dir)
    out_dir.mkdir(parents=True, exist_ok=True)

    color_map = {"Low": "#7ed957", "Medium": "#ffc107", "High": "#ff4d4d"}
    color = color_map.get(risk, "#cccccc")

    # Matplotlib chart
    fig, ax = plt.subplots(figsize=(6, 1))
    ax.barh(["Risk Score"], [score], color=color)
    ax.set_xlim(0, 100)
    ax.set_xlabel("0 (Low) ←→ 100 (High)")
    ax.set_title(f"Risk Level: {risk}")
    fig.tight_layout()
    chart_path = out_dir / "risk_chart.png"
    fig.savefig(chart_path)
    plt.close(fig)

    # HTML
    html_path = out_dir / "risk_dashboard.html"
    html = f"""
<html>
<head><title>T.E.M.P.E.S.T. Risk Dashboard</title></head>
<body style='font-family:Segoe UI; background:#0f111a; color:#ddd; padding:30px'>
<h1>🛰️ T.E.M.P.E.S.T. Risk Dashboard</h1>
<p>Generated: {datetime.now().strftime("%Y-%m-%d %H:%M:%S")}</p>
<div style='font-size:72px; color:{color}'>{score}</div>
<div style='font-size:28px; color:{color}'>Risk Level: {risk}</div>
<img src='risk_chart.png' alt='Risk Chart' style='width:80%; border-radius:8px; margin-top:20px;'>
<h2>Key Findings</h2>
<ul>
{''.join(f"<li>{n}</li>" for n in notes)}
</ul>
</body>
</html>
"""
    html_path.write_text(html, encoding="utf-8")
    return html_path, chart_path


# --------------------------
# MAIN
# --------------------------
def main():
    if len(sys.argv) < 2:
        print("Usage: python analyze_tempest.py <csv_path>")
        sys.exit(1)

    csv_path = Path(sys.argv[1])
    if not csv_path.exists():
        print(f"[ERROR] File not found: {csv_path}")
        sys.exit(1)

    df = pd.read_csv(csv_path)

    score, risk, notes = calculate_risk(df)

    # Save JSON
    out_dir = Path("./output")
    out_dir.mkdir(exist_ok=True)
    json_path = out_dir / "risk_report.json"
    with json_path.open("w", encoding="utf-8") as f:
        json.dump({
            "timestamp": datetime.now().isoformat(),
            "risk_score": score,
            "risk_level": risk,
            "findings": notes
        }, f, indent=2)

    # Save summary text
    summary_path = out_dir / "summary.txt"
    with summary_path.open("w", encoding="utf-8") as f:
        f.write(f"T.E.M.P.E.S.T. Summary Report\nGenerated: {datetime.now()}\nRisk Score: {score}\nRisk Level: {risk}\n\nFindings:\n")
        for n in notes:
            f.write(f" - {n}\n")

    # Build HTML dashboard
    html_path, chart_path = build_dashboard(score, risk, notes, out_dir)

    print(f"[AI] Risk Score: {score} ({risk})")
    print("[AI] Reports generated:")
    print(f" - {json_path.name}")
    print(f" - {summary_path.name}")
    print(f" - {html_path.name}")
    print(f" - {chart_path.name}")


if __name__ == "__main__":
    main()
