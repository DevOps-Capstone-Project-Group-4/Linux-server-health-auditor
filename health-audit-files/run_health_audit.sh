#!/bin/bash
set -o pipefail

# Wrapper script for automated health audit with notifications and structured logging

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
AUDIT_SCRIPT="$SCRIPT_DIR/health_audit.sh"
LOG_FILE="$SCRIPT_DIR/health_audit.log"
JSON_LOG_FILE="$SCRIPT_DIR/health_audit_results.jsonl"
LOCK_FILE="/tmp/health-audit-$(hostname).lock"
ALERT_CONFIG="$SCRIPT_DIR/alert.env"
MAX_LOG_SIZE=$((10 * 1024 * 1024))  # 10MB

# Load alert configuration if exists
ALERT_EMAIL=""
ALERT_SLACK_WEBHOOK=""
if [ -f "$ALERT_CONFIG" ]; then
    source "$ALERT_CONFIG"
fi

# Implement locking to prevent concurrent runs
acquire_lock() {
    local timeout=30
    local elapsed=0
    while [ -f "$LOCK_FILE" ] && [ $elapsed -lt $timeout ]; do
        sleep 1
        ((elapsed++))
    done
    if [ -f "$LOCK_FILE" ]; then
        echo "ERROR: Another audit is already running (lock older than ${timeout}s)" >&2
        return 1
    fi
    echo $$ > "$LOCK_FILE"
    return 0
}

release_lock() {
    rm -f "$LOCK_FILE"
}

# Rotate log files if they exceed max size
rotate_logs() {
    local log=$1
    if [ -f "$log" ] && [ $(stat -f%z "$log" 2>/dev/null || stat -c%s "$log" 2>/dev/null) -gt $MAX_LOG_SIZE ]; then
        mv "$log" "$log.$(date +%s)"
        gzip "$log.$(date +%s)" &>/dev/null &
        echo "[$(date -u '+%Y-%m-%dT%H:%M:%SZ')] Log rotated due to size limit" >> "$log"
    fi
}

# Send email alert
send_email_alert() {
    local subject=$1
    local body=$2
    if command -v mail >/dev/null 2>&1 && [ -n "$ALERT_EMAIL" ]; then
        echo "$body" | mail -s "$subject" "$ALERT_EMAIL" 2>/dev/null || true
    fi
}

# Send Slack notification
send_slack_alert() {
    local message=$1
    local status_color=$2
    if [ -n "$ALERT_SLACK_WEBHOOK" ] && command -v curl >/dev/null 2>&1; then
        curl -X POST "$ALERT_SLACK_WEBHOOK" \
            -H 'Content-Type: application/json' \
            -d "{\"attachments\": [{\"color\": \"$status_color\", \"title\": \"Server Health Alert: $(hostname)\", \"text\": \"$message\"}]}" \
            2>/dev/null || true
    fi
}

# Main execution
trap release_lock EXIT

if ! acquire_lock; then
    exit 1
fi

# Rotate logs if needed
rotate_logs "$LOG_FILE"
rotate_logs "$JSON_LOG_FILE"

# Run audit and capture output
audit_output=$(bash "$AUDIT_SCRIPT" 2>&1)
exit_code=$?

# Log with timestamp
{
    echo "[$(date -u '+%Y-%m-%dT%H:%M:%SZ')] Health Audit Run Started"
    echo "$audit_output"
    echo "[$(date -u '+%Y-%m-%dT%H:%M:%SZ')] Exit Code: $exit_code"
    echo "---"
} >> "$LOG_FILE" 2>&1

# Extract and store JSON output as one compact JSONL line
json_output=$(echo "$audit_output" | awk 'BEGIN{capture=0} /^\{/ {capture=1} capture {print} /^\}$/ {if (capture) exit}')
if [ -n "$json_output" ]; then
    json_line=$(printf '%s\n' "$json_output" | python3 -c 'import json,sys; print(json.dumps(json.load(sys.stdin), separators=(",", ":")))' 2>/dev/null || true)

    if [ -n "$json_line" ]; then
        printf '%s\n' "$json_line" >> "$JSON_LOG_FILE"

        # Check for critical/warning status and send alerts
        system_status=$(printf '%s\n' "$json_line" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("system_status", ""))' 2>/dev/null || true)

        if [ "$system_status" = "CRITICAL" ]; then
            alert_msg="CRITICAL: $(printf '%s\n' "$json_line" | python3 -c 'import json,sys; data=json.load(sys.stdin); print("cpu=%s memory=%s disk=%s" % (data["cpu"]["usage"], data["memory"]["usage"], data["disk"]["usage"]))' 2>/dev/null || true)"
            send_email_alert "Server CRITICAL Alert: $(hostname)" "$json_line"
            send_slack_alert "$alert_msg" "danger"
        elif [ "$system_status" = "WARNING" ]; then
            alert_msg="WARNING: $(printf '%s\n' "$json_line" | python3 -c 'import json,sys; data=json.load(sys.stdin); print("cpu=%s memory=%s disk=%s" % (data["cpu"]["usage"], data["memory"]["usage"], data["disk"]["usage"]))' 2>/dev/null || true)"
            send_slack_alert "$alert_msg" "warning"
        fi
    fi
fi

exit $exit_code
