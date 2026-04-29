# 🚀 Linux Server Health Auditor

![DevOps](https://img.shields.io/badge/DevOps-Automation-blue)
![Bash](https://img.shields.io/badge/Bash-Scripting-black)
![Prometheus](https://img.shields.io/badge/Monitoring-Prometheus-orange)
![Docker](https://img.shields.io/badge/Container-Docker-blue)
![Status](https://img.shields.io/badge/Status-Active-brightgreen)

---

## 🧠 Project Overview
## ⚙️ Automation & Monitoring

This project implements automated system health monitoring using a Bash script and cron scheduling.

The script collects:
- CPU usage
- Memory usage
- Disk usage

These metrics are evaluated against thresholds to determine system status:
- OK
- WARNING
- CRITICAL

---

### 🔄 Automation (Cron)

The script runs automatically every 5 minutes:

```bash
*/5 * * * * /bin/bash health_audit.sh



---

## 📊 Architecture
                 ┌──────────────────────────┐
                 │      Cron Scheduler      │
                 │   (runs every 5 mins)    │
                 └──────────┬───────────────┘
                            │
                            v
                 ┌──────────────────────────┐
                 │  Bash Health Script      │
                 │ (CPU / MEM / DISK check) │
                 └──────────┬───────────────┘
                            │
          ┌──────────────────┴──────────────────┐
          │                                     │
          v                                     v
┌──────────────────────┐            ┌────────────────────────┐
│  JSON Health Report  │            │ Prometheus Metrics File │
│  (logs/health.log)   │            │  (metrics.prom)        │
└──────────────────────┘            └──────────┬─────────────┘
                                               │
                                               v
                              ┌──────────────────────────┐
                              │  Prometheus (Docker)     │
                              │  Scrapes metrics file    │
                              └──────────┬───────────────┘
                                         │
                                         v
                              ┌──────────────────────────┐
                              │   Monitoring Dashboard    │
                              │   (http://localhost:9090) │
                              └──────────────────────────┘

---

## ⚙️ Key Features

- 🔄 Automated system monitoring using Cron
- 📊 Real-time metrics collection (CPU, Memory, Disk)
- 🚨 Threshold-based alert logic (OK / WARNING / CRITICAL)
- 📦 Prometheus integration for observability
- 🐳 Docker-based deployment for portability
- 💡 Fully local, no cloud cost required

---

## ▶️ How to Run

### 1️⃣ Navigate to project folder

```bash
cd Linux-server-health-auditor/health-audit-files

###2.Make script executable
chmod +x health_audit.sh

### 3.Run manually (test)
./health_audit.sh

###4️⃣ Enable automation (Cron - every 5 mins)
crontab -e

Add:

*/5 * * * * /bin/bash $HOME/Linux-server-health-auditor/health-audit-files/health_audit.sh

###5️⃣ Start Prometheus (Docker)
docker run -d \
  --name prometheus \
  -p 9090:9090 \
  -v $HOME/metrics:/metrics \
  -v $PWD/prometheus.yml:/etc/prometheus/prometheus.yml \
  prom/prometheus


###6️⃣ Open Dashboard

👉 http://localhost:9090

Search metrics:

cpu_usage
memory_usage
disk_usage


###🔁 Restart Guide

If system restarts:

cd ~/Linux-server-health-auditor/health-audit-files
./health_audit.sh
docker start prometheus
