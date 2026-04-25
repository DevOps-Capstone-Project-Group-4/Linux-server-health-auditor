#!/bin/bash

## Define the threshold values for CPU, memory, and disk usage (in percentage)
CONFIG_FILE="./threshold.env"
[ -f "$CONFIG_FILE" ] && . "$CONFIG_FILE"


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

cpu_usage=$(get_cpu)
memory_usage=$(get_memory)
disk_usage=$(get_disk)

cpu_status=$(check_status "$cpu_usage" "$CPU_WARN" "$CPU_CRIT")
memory_status=$(check_status "$memory_usage" "$MEM_WARN" "$MEM_CRIT")
disk_status=$(check_status "$disk_usage" "$DISK_WARN" "$DISK_CRIT")

echo "CPU_WARN=$CPU_WARN CPU_CRIT=$CPU_CRIT"
echo "MEM_WARN=$MEM_WARN MEM_CRIT=$MEM_CRIT"
echo "DISK_WARN=$DISK_WARN DISK_CRIT=$DISK_CRIT"

timestamp=$(date "+%Y-%m-%d %H:%M:%S")

#overall system status

if [[ "$cpu_status" == "CRITICAL" || "$memory_status" == "CRITICAL" || "$disk_status" == "CRITICAL" ]]; then
  system_status="CRITICAL"
elif [[ "$cpu_status" == "WARNING" || "$memory_status" == "WARNING" || "$disk_status" == "WARNING" ]]; then
  system_status="WARNING"
else
  system_status="OK"
fi

#output

cat <<EOF
{
  "timestamp": "$timestamp",
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
