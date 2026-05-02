#!/bin/bash
set -o pipefail  # Exit on pipe failures

## Define script directory (portable path for group projects)
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

## Load threshold config safely using absolute path
CONFIG_FILE="$SCRIPT_DIR/threshold.env"

if [ ! -f "$CONFIG_FILE" ]; then
  echo "ERROR: threshold.env not found at $CONFIG_FILE" >&2
  exit 1
fi

source "$CONFIG_FILE" || { echo "ERROR: Failed to source $CONFIG_FILE" >&2; exit 1; }

# Validate threshold values (must be 0-100 and warn < crit)
validate_thresholds() {
  local warn=$1 crit=$2 name=$3
  if ! [[ "$warn" =~ ^[0-9]+$ ]] || ! [[ "$crit" =~ ^[0-9]+$ ]]; then
    echo "ERROR: Invalid $name threshold values (must be integers)" >&2
    return 1
  fi
  if [ "$warn" -ge "$crit" ]; then
    echo "ERROR: $name warning ($warn) must be less than critical ($crit)" >&2
    return 1
  fi
  if [ "$warn" -lt 0 ] || [ "$warn" -gt 100 ] || [ "$crit" -lt 0 ] || [ "$crit" -gt 100 ]; then
    echo "ERROR: $name thresholds must be between 0-100" >&2
    return 1
  fi
  return 0
}

# Validate all thresholds at startup
validate_thresholds "$CPU_WARN" "$CPU_CRIT" "CPU" || exit 1
validate_thresholds "$MEM_WARN" "$MEM_CRIT" "MEMORY" || exit 1
validate_thresholds "$DISK_WARN" "$DISK_CRIT" "DISK" || exit 1

# check warning
command -v df >/dev/null 2>&1 || { echo "Warning: df not found" >&2; exit 1; }

# Monitoring usage

get_cpu() {
  read -r cpu user nice system idle iowait irq softirq steal guest < /proc/stat
  total1=$((user+nice+system+idle+iowait+irq+softirq+steal))
  idle1=$idle

  sleep 1

  read -r cpu user nice system idle iowait irq softirq steal guest < /proc/stat
  total2=$((user+nice+system+idle+iowait+irq+softirq+steal))
  idle2=$idle

  total=$((total2-total1))
  idle_diff=$((idle2-idle1))

  if [ "$total" -eq 0 ]; then
    echo 0
  else
    echo $((100 * (total - idle_diff) / total))
  fi
}

get_memory() {
  awk '
    /MemTotal/ {total=$2}
    /MemFree/ {free=$2}
    /Buffers/ {buffers=$2}
    /Cached/ {cached=$2}

    END {
      used = total - free - buffers - cached

      if (total > 0)
        printf("%.2f", (used / total) * 100)
      else
        print 0
    }
  ' /proc/meminfo
}

get_disk() {
  df / --output=pcent | tail -n 1 | tr -dc '0-9'
}

check_status() {
  value=${1%.*}
  warn=$2
  crit=$3

  if [ "$value" -ge "$crit" ]; then
    echo "CRITICAL"
  elif [ "$value" -ge "$warn" ]; then
    echo "WARNING"
  else
    echo "OK"
  fi
}

cpu_usage=$(get_cpu)
memory_usage=$(get_memory)
disk_usage=$(get_disk)

cpu_status=$(check_status "$cpu_usage" "$CPU_WARN" "$CPU_CRIT")
memory_status=$(check_status "$memory_usage" "$MEM_WARN" "$MEM_CRIT")
disk_status=$(check_status "$disk_usage" "$DISK_WARN" "$DISK_CRIT")

timestamp=$(date -u "+%Y-%m-%dT%H:%M:%SZ")  # ISO 8601 UTC format

#overall system status

if [[ "$cpu_status" == "CRITICAL" || "$memory_status" == "CRITICAL" || "$disk_status" == "CRITICAL" ]]; then
  system_status="CRITICAL"
elif [[ "$cpu_status" == "WARNING" || "$memory_status" == "WARNING" || "$disk_status" == "WARNING" ]]; then
  system_status="WARNING"
else
  system_status="OK"
fi

echo "{"
cat <<EOF
  "host": "$(hostname)",
  "timestamp": "$timestamp",
  "system_status": "$system_status",
  "cpu": {
    "usage": $cpu_usage,
    "status": "$cpu_status",
    "warning_threshold": $CPU_WARN,
    "critical_threshold": $CPU_CRIT
  },
  "memory": {
    "usage": $memory_usage,
    "status": "$memory_status",
    "warning_threshold": $MEM_WARN,
    "critical_threshold": $MEM_CRIT
  },
  "disk": {
    "usage": $disk_usage,
    "status": "$disk_status",
    "warning_threshold": $DISK_WARN,
    "critical_threshold": $DISK_CRIT
  }
}
EOF

# Write Prometheus metrics to the file Prometheus or node_exporter reads
METRICS_FILE="$SCRIPT_DIR/metrics.prom"
{
  echo "# HELP cpu_usage CPU usage percentage"
  echo "# TYPE cpu_usage gauge"
  echo "cpu_usage{host=\"$(hostname)\"} ${cpu_usage:-0}"
  echo "# HELP memory_usage Memory usage percentage"
  echo "# TYPE memory_usage gauge"
  echo "memory_usage{host=\"$(hostname)\"} ${memory_usage:-0}"
  echo "# HELP disk_usage Disk usage percentage"
  echo "# TYPE disk_usage gauge"
  echo "disk_usage{host=\"$(hostname)\"} ${disk_usage:-0}"
} > "$METRICS_FILE"
