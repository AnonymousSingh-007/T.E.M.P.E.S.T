# T.E.M.P.E.S.T. ⚡🛡️

![Platform](https://img.shields.io/badge/platform-Windows-blue?style=flat-square)
![Language](https://img.shields.io/badge/PowerShell-7%2B-blue?style=flat-square)
![Python](https://img.shields.io/badge/Python-3.9%2B-yellow?style=flat-square)
![ML](https://img.shields.io/badge/ML-Unsupervised%20Anomaly%20Detection-purple?style=flat-square)
![License](https://img.shields.io/badge/License-MIT-green?style=flat-square)
![Status](https://img.shields.io/badge/Status-Defensive%20Security-critical?style=flat-square)

**Threat-surface Enumeration: Modules, Ports, Extensions, Schedules & Tasks**

Recon complete — deliver actionable telemetry.

**T.E.M.P.E.S.T.** is a focused, **read-only Windows attack-surface enumerator** built primarily in **PowerShell**, with optional **Python-based ML anomaly detection**. It collects host telemetry (services, listening ports, autostart vectors, firewall rules, scheduled tasks, drivers, browser extensions) and produces **machine-readable artifacts (JSON / CSV)** plus a **lightweight HTML dashboard** for human triage.

Mission: **visibility → prioritization → defensive hardening**. 🎯

---

## ⚠️ WARNING / RULES OF ENGAGEMENT

Only run T.E.M.P.E.S.T. on systems you **own** or have **explicit written authorization** to audit.

Unauthorized enumeration may be illegal or violate policy.  
This tool is **read-only by design** — no exploitation, no persistence, no modification.

Treat outputs as **sensitive security intelligence**:
- Encrypt at rest
- Restrict access
- Do not upload to public trackers or paste sites 🔐

---

## 🔗 Quick links

- **Entrypoint:** `src/Public/Invoke-Tempest.ps1`
- **Core modules:** `src/Private/`
- **ML analysis:** `analysis/anomaly/`
- **Outputs:** CSV (per section), combined CSV, JSON, HTML dashboard
- **CI:** GitHub Actions (Windows runner recommended)

---

## ✅ Features — what T.E.M.P.E.S.T. collects

### Core enumeration
- **Host summary** (OS, build, architecture, elevation, hostname)
- **Services** (state, start type, binary path, account)
- **Listening ports** (TCP/UDP, local address, PID, owning process)
- **Autostart vectors**
  - Registry `Run` keys
  - Startup folders
  - Scheduled-task–based persistence
- **Firewall rules** (direction, action, program, ports)
- **Scheduled tasks** (triggers, actions, principals, run context)
- **Drivers** (installed drivers, signing state)
- **Browser extensions**
  - Chrome / Edge / Firefox (manifest-based)
- **Optional process correlation** (PID ↔ service ↔ port)

### 🧠 ML-assisted anomaly detection (optional)
If a Python virtual environment is present, T.E.M.P.E.S.T. runs **unsupervised ML** against:

- Listening ports
- Services
- Autostart entries

Each row receives:
- `AnomalyScore`
- `IsAnomaly` (True / False)

⚠️ ML output is **assistive, not authoritative** — always review context.

---

## 🏁 Install & run (fast start)

### Requirements

- Windows 10 / 11 or Windows Server
- PowerShell 5.1+ (PowerShell 7+ recommended)
- Administrator privileges recommended (for full visibility)

Optional (for ML):
- Python 3.9+
- Virtual environment support

---

## 🧾 How it works — technical overview

-PowerShell modules enumerate host data into structured objects

-CSVs are generated per section

-Python ML scripts score records (if enabled)

-Scored data is re-ingested into the report object

-JSON, combined CSV, and HTML dashboard are generated

-Failures are logged but do not halt execution.

---
### Clone

```bash
git clone https://github.com/AnonymousSingh-007/T.E.M.P.E.S.T.git
cd T.E.M.P.E.S.T
