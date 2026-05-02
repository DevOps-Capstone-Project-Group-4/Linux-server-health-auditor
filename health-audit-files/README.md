## Linux Server Health Auditor

### DevOps Bash Prometheus Docker Status

#### Project Overview

 #### Automation & Monitoring
 
This project implements automated system health monitoring using a Bash script and cron scheduling.

The script collects:

CPU usage
Memory usage
Disk usage
These metrics are evaluated against thresholds to determine system status:

OK
WARNING
CRITICAL

#### Automation (Cron)

The script runs automatically every 5 minutes:

*/5 * * * * /bin/bash health_audit.sh


#### Architecture

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

#### Key Features

- 🔄 Automated system monitoring using Cron
- 📊 Real-time metrics collection (CPU, Memory, Disk)
- 🚨 Threshold-based alert logic (OK / WARNING / CRITICAL)
- 📦 Prometheus integration for observability
- 🐳 Docker-based deployment for portability
- 💡 Fully local, no cloud cost required

---

#### How to Run

#### Navigate to project folder


cd Linux-server-health-auditor/health-audit-files

#### 2.Make script executable
chmod +x health_audit.sh

#### 3.Run manually (test)
./health_audit.sh

#### 4️ Enable automation (Cron - every 5 mins)
crontab -e

####  Start Prometheus + node-exporter (Linux-safe Docker setup)

From the project root (`Linux-server-health-auditor`), run:

```bash
# Keep metrics file fresh
bash health-audit-files/health_audit.sh >/dev/null

# Clean up old demo containers if they exist
docker rm -f prometheus node-exporter-audit 2>/dev/null || true

# Create a dedicated network for container-to-container DNS
docker network create health-audit-net 2>/dev/null || true

# Expose metrics.prom via node_exporter textfile collector
docker run -d \
  --name node-exporter-audit \
  --network health-audit-net \
  -p 9101:9100 \
  -v "$(pwd)/health-audit-files:/textfile:ro" \
  prom/node-exporter \
  --collector.textfile.directory=/textfile

# Start Prometheus with this repo's config
docker run -d \
  --name prometheus \
  --network health-audit-net \
  -p 9091:9090 \
  -v "$(pwd)/health-audit-files/prometheus.yml:/etc/prometheus/prometheus.yml:ro" \
  prom/prometheus
```


#### 6️ Open Dashboard

👉 http://localhost:9091

Search metrics:

cpu_usage
memory_usage
disk_usage

Quick checks:

```bash
curl -s http://localhost:9101/metrics | grep -E 'cpu_usage|memory_usage|disk_usage'
curl -s 'http://localhost:9091/api/v1/query?query=up'
```


#### Restart Guide

If system restarts:

cd ~/Linux-server-health-auditor/health-audit-files
./health_audit.sh
docker start node-exporter-audit
docker start prometheus

