#!/bin/bash

## Load config file
CONFIG_FILE="./threshold.env"
[ -f "$CONFIG_FILE" ] && . "$CONFIG_FILE"

## Default fallback values
CPU_WARN=${CPU_WARN:-70}
CPU_CRIT=${CPU_CRIT:-85}
MEM_WARN=${MEM_WARN:-70}
MEM_CRIT=${MEM_CRIT:-85}
DISK_WARN=${DISK_WARN:-80}
DISK_CRIT=${DISK_CRIT:-90}

## Create logs directory
mkdir -p logs
LOG_FILE="./logs/monitor.log"
JSON_LOG="./logs/monitor.json"

# check warning
command -v df >/dev/null 2>&1 || echo "Warning: df not found"

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

human_output() {
  cat <<EOF
[$timestamp] SYSTEM STATUS: $system_status
CPU: ${cpu_usage}% ($cpu_status)
MEMORY: ${memory_usage}% ($memory_status)
DISK: ${disk_usage}% ($disk_status)
EOF
}

cpu_usage=$(get_cpu)
memory_usage=$(get_memory)
disk_usage=$(get_disk)

cpu_status=$(check_status "$cpu_usage" "$CPU_WARN" "$CPU_CRIT")
memory_status=$(check_status "$memory_usage" "$MEM_WARN" "$MEM_CRIT")
disk_status=$(check_status "$disk_usage" "$DISK_WARN" "$DISK_CRIT")

timestamp=$(date "+%Y-%m-%d %H:%M:%S")

# overall system status
if [[ "$cpu_status" == "CRITICAL" || "$memory_status" == "CRITICAL" || "$disk_status" == "CRITICAL" ]]; then
  system_status="CRITICAL"
elif [[ "$cpu_status" == "WARNING" || "$memory_status" == "WARNING" || "$disk_status" == "WARNING" ]]; then
  system_status="WARNING"
else
  system_status="OK"
fi

# JSON output
json_output=$(cat <<EOF
{
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
)

# ==============================
# LOG ROTATION
# ==============================
MAX_SIZE=1000000  # 1MB

if [ -f "$LOG_FILE" ]; then
  FILE_SIZE=$(stat -c%s "$LOG_FILE" 2>/dev/null || stat -f%z "$LOG_FILE" 2>/dev/null || echo 0)

  if [ "$FILE_SIZE" -ge "$MAX_SIZE" ]; then
    mv "$LOG_FILE" "logs/monitor_$(date +%Y%m%d%H%M%S).log"
  fi
fi

# Save human-readable log
echo "----------------------------------------" >> "$LOG_FILE"
human_output >> "$LOG_FILE"

# Save JSON log  
echo "$json_output" >> "$JSON_LOG"

# ==============================
# TERMINAL OUTPUT (NEW)
# ==============================
human_output
echo ""
echo "$json_output"