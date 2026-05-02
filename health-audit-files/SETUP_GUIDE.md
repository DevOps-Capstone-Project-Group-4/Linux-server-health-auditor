# Health Audit System: Complete Setup & Operations Guide

##  Overview

This guide covers the improved health audit system with:
- Automated scheduling via systemd timers (every 5 minutes)
- Structured logging (human-readable + JSONL)
- Self-monitoring health checks
- Lock file mechanism for concurrent run prevention
- Log rotation for disk space management

---

##  Quick Start

### 1. Make Scripts Executable
```bash
chmod +x health-audit-files/*.sh
```

### 2. Test the Audit Script
cd into the `health-audit-files` directory and run:
```bash
./health_audit.sh
```

Expected output: JSON with CPU, memory, and disk metrics.

### 3. Configure Thresholds (Optional)
Edit `threshold.env`:
```bash
CPU_WARN=70    # Warning at 70%
CPU_CRIT=85    # Critical at 85%
MEM_WARN=70
MEM_CRIT=85
DISK_WARN=75
DISK_CRIT=90
```


## 🛠️ Installation Methods

### Option A: Systemd Timers (Recommended - Modern)

**Pros:** Automatic on reboot, integrated logging, better reliability
**Cons:** Requires root access

Use `sudo ./install-systemd.sh` to install the service and timers. Do not manually copy the unit files into `/etc/systemd/system/`; the install script generates portable launcher scripts in `/usr/local/bin`, so the service works from whatever directory the repo is cloned into.
cd into the `health-audit-files` directory and run:

```bash
sudo ./install-systemd.sh
```

Verify installation:
```bash
sudo systemctl list-timers health-audit.timer
sudo systemctl status health-audit.timer
```

### Option B: Cron Job (Legacy)

**Pros:** Simple, no root needed
**Cons:** Not integrated with systemd, limited logging

In systemd, scheduling is handled through Timer Units (files ending in .timer), which act as a more powerful, integrated alternative to the traditional cron utility. Unlike cron, a systemd timer does not execute a command directly; instead, it triggers a corresponding Service Unit (ending in .service) that defines the actual task.

```bash
crontab -e

# Add this line:
*/5 * * * * /path/to/run_health_audit.sh

# Optional: Clean up old logs every Sunday
0 0 * * 0 find /path/to -name "health_audit*.log*" -mtime +7 -delete
```

---

## 📊 Output & Logging

### Log Files Created

| File | Purpose | Format |
|------|---------|--------|
| `health_audit.log` | Timestamped text logs | Human-readable |
| `health_audit_results.jsonl` | Time-series metrics | JSONL (one JSON per line) |
| `metrics.prom` | Prometheus metrics | Prometheus format |

### Example Output

```json
{
  "host": "server1",
  "timestamp": "2026-05-02T10:30:45Z",
  "system_status": "OK",
  "cpu": {
    "usage": 45.67,
    "status": "OK",
    "warning_threshold": 70,
    "critical_threshold": 85
  },
  "memory": {
    "usage": 62.34,
    "status": "OK",
    "warning_threshold": 70,
    "critical_threshold": 85
  },
  "disk": {
    "usage": 68,
    "status": "OK",
    "warning_threshold": 75,
    "critical_threshold": 90
  }
}
```

### Viewing Logs

```bash
# Real-time monitoring (systemd)
sudo journalctl -u health-audit.service -f

# View recent runs
tail -50 health_audit.log

# Parse JSONL for specific metrics
cat health_audit_results.jsonl | jq '.cpu.usage'

# Find critical alerts
grep -i critical health_audit.log
```

---


## ✅ Self-Monitoring & Health Checks

The system monitors itself to ensure the monitor doesn't fail silently.

### Manual Health Check
```bash
./health_check.sh
```

**Checks include:**
- Last log update within 10 minutes
- Valid JSON in results
- Scripts are executable
- Disk space available for logs

### Automatic Health Check
Runs every 10 minutes via systemd timer:
```bash
sudo systemctl status health-audit-check.timer
```

---

## 🔄 Systemd Management

### Common Commands

| Command | Purpose |
|---------|---------|
| `sudo systemctl status health-audit.timer` | Check timer status |
| `sudo systemctl list-timers health-audit.timer` | View next run time |
| `sudo systemctl start health-audit.service` | Run audit immediately |
| `sudo systemctl start health-audit.timer` | Enable/start timer |
| `sudo systemctl stop health-audit.timer` | Stop timer |
| `sudo journalctl -u health-audit.service -n 50` | View last 50 log entries |
| `sudo journalctl -u health-audit.service --since "10 minutes ago"` | Logs from last 10 mins |

### Running Manually
```bash
# Trigger audit immediately
sudo systemctl start health-audit.service

# Check result
sudo journalctl -u health-audit.service -n 5
```

---

## 🐛 Troubleshooting

### Timer Not Running

```bash
# Verify unit files are installed
sudo systemctl status health-audit.timer

# Check for errors
sudo journalctl -u health-audit.timer -n 30

# Manually start timer
sudo systemctl start health-audit.timer

# Verify it's active
sudo systemctl is-active health-audit.timer
```

### Permission Denied

```bash
# Ensure scripts are executable
chmod +x health_audit.sh run_health_audit.sh health_check.sh

# Systemd services need to run as root
# If non-root, add to sudoers:
# youruser ALL=(ALL) NOPASSWD: /path/to/health_audit.sh
```

### Lock File Issues

```bash
# If stuck with old lock file:
rm -f /tmp/health-audit-$(hostname).lock

# Check for stuck processes
ps aux | grep health_audit
```

### Memory/CPU Readings Wrong

```bash
# Validate threshold.env values
cat threshold.env

# Check that /proc/stat is readable
cat /proc/stat | head -3

# Run manually to see raw output
./health_audit.sh | jq '.cpu.usage'
```

---

## Integration Examples

### Prometheus Scrape Config
Add to `prometheus.yml`:
```yaml
scrape_configs:
  - job_name: 'health_audit'
    static_configs:
      - targets: ['localhost:9100']
    metrics_path: '/path/to/metrics.prom'
    scrape_interval: 5m
```

### Grafana Dashboard Query
```promql
# CPU usage (5min average)
avg_over_time(cpu_usage[5m])

# Memory spike detection
rate(memory_usage[1m]) > 0.5

# Disk usage trend
disk_usage
```

### Query JSONL Logs
```bash
# Latest 5 runs
tail -5 health_audit_results.jsonl | jq -s 'sort_by(.timestamp)'

# Average CPU over time
cat health_audit_results.jsonl | jq '.cpu.usage' | awk '{sum+=$1; count++} END {print sum/count}'

# Find when disk exceeded 80%
grep -P '"disk".*?"usage":\s*(?:8[0-9]|9[0-9]|100)' health_audit_results.jsonl
```

---

## 🔐 Security Considerations

1. **Permissions**: Service runs as root; restrict file access
   ```bash
   chmod 600 alert.env  # Only root can read
   chmod 755 health_audit.sh  # Scripts readable by all
   ```

---

## 📝 Uninstalling

### Systemd Timers
```bash
sudo ./uninstall-systemd.sh
```

### Cron Jobs
```bash
crontab -e
# Remove the health audit lines
```

---

## Key Improvements Over Cron

| Feature | Cron | Systemd |
|---------|------|---------|
| **Boot reliability** | May miss runs | Guaranteed |
| **Logging** | `/var/log/cron` only | Full journald integration |
| **Dependencies** | Limited | Can wait for network, dependencies |
| **Randomization** | Manual scripting | Built-in `RandomizedDelaySec` |
| **Monitoring** | Manual checks | `systemctl status`, `list-timers` |
| **Error handling** | Cron errors hidden | All errors in journal |
| **CPU spreading** | All at once | Use `RandomizedDelaySec` |

---

