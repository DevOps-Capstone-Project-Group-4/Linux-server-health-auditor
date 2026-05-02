#!/bin/bash
# Simple health check for the audit system
# Verifies that the monitoring is still running and producing valid output

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
LOG_FILE="$SCRIPT_DIR/health_audit.log"
JSON_LOG_FILE="$SCRIPT_DIR/health_audit_results.jsonl"
ALERT_CONFIG="$SCRIPT_DIR/alert.env"
RECENT_THRESHOLD=600  # 10 minutes in seconds

# Load alert settings if they exist
ALERT_EMAIL=""
ALERT_SLACK_WEBHOOK=""
if [ -f "$ALERT_CONFIG" ]; then
    source "$ALERT_CONFIG"
fi

check_log_recent() {
    local log=$1
    if [ ! -f "$log" ]; then
        echo "Log file missing: $log"
        return 1
    fi

    local mtime=$(stat -c%Y "$log" 2>/dev/null || stat -f%m "$log" 2>/dev/null)
    local now=$(date +%s)
    local age=$((now - mtime))

    if [ $age -gt $RECENT_THRESHOLD ]; then
        echo "Health audit is stale. Last update was ${age}s ago."
        return 1
    fi

    return 0
}

check_json_valid() {
    local json_log=$1
    if [ ! -f "$json_log" ]; then
        echo "JSONL log missing: $json_log"
        return 1
    fi

    # Validate the newest JSON object in the file
    local last_line=$(tail -n 1 "$json_log")
    if ! echo "$last_line" | python3 -c 'import json,sys; json.load(sys.stdin)' 2>/dev/null; then
        echo "Invalid JSON found in: $json_log"
        return 1
    fi

    return 0
}

check_script_executable() {
    local script=$1
    if [ ! -x "$script" ]; then
        echo "Script is not executable: $script"
        return 1
    fi

    return 0
}

check_disk_for_logs() {
    local log_dir=$(dirname "$LOG_FILE")
    local disk_usage=$(df "$log_dir" --output=pcent | tail -n 1 | tr -dc '0-9')
    if [ "$disk_usage" -gt 90 ]; then
        echo "Disk usage in the log directory is ${disk_usage}%"
        return 1
    fi

    return 0
}

run_check() {
    local label="$1"
    shift

    if "$@"; then
        echo "✅ $label"
        return 0
    fi

    echo "❌ $label"
    return 1
}

failed=0

run_check "Recent log file" check_log_recent "$LOG_FILE" || failed=1
run_check "Valid JSONL output" check_json_valid "$JSON_LOG_FILE" || failed=1
run_check "Audit script executable" check_script_executable "$SCRIPT_DIR/health_audit.sh" || failed=1
run_check "Wrapper script executable" check_script_executable "$SCRIPT_DIR/run_health_audit.sh" || failed=1
run_check "Enough disk space for logs" check_disk_for_logs || failed=1

if [ "$failed" -eq 0 ]; then
    echo "All health checks passed"
    exit 0
fi

echo "Health check failed"
exit 1
