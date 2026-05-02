#!/bin/bash
# Installation script for systemd timer and service setup
# Run this with sudo to install the health audit as a system service

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SERVICE_DIR="/etc/systemd/system"
BIN_DIR="/usr/local/bin"

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "=========================================="
echo "Health Audit Systemd Installation"
echo "=========================================="

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}ERROR: This installation script must be run with sudo${NC}"
    exit 1
fi

# Verify all scripts are executable
echo -e "${YELLOW}Checking scripts...${NC}"
chmod +x "$SCRIPT_DIR/health_audit.sh" || { echo "Failed to make health_audit.sh executable"; exit 1; }
chmod +x "$SCRIPT_DIR/run_health_audit.sh" || { echo "Failed to make run_health_audit.sh executable"; exit 1; }
chmod +x "$SCRIPT_DIR/health_check.sh" || { echo "Failed to make health_check.sh executable"; exit 1; }

# Install systemd service and timer files
echo -e "${YELLOW}Installing systemd unit files...${NC}"
cat > "$BIN_DIR/health-audit-runner" <<EOF
#!/bin/bash
exec "$SCRIPT_DIR/run_health_audit.sh" "\$@"
EOF
cat > "$BIN_DIR/health-audit-check-runner" <<EOF
#!/bin/bash
exec "$SCRIPT_DIR/health_check.sh" "\$@"
EOF
chmod +x "$BIN_DIR/health-audit-runner" "$BIN_DIR/health-audit-check-runner"
cp "$SCRIPT_DIR/health-audit.service" "$SERVICE_DIR/health-audit.service" || { echo "Failed to install health-audit.service"; exit 1; }
cp "$SCRIPT_DIR/health-audit.timer" "$SERVICE_DIR/health-audit.timer" || { echo "Failed to install health-audit.timer"; exit 1; }
cp "$SCRIPT_DIR/health-audit-check.service" "$SERVICE_DIR/health-audit-check.service" || { echo "Failed to install health-audit-check.service"; exit 1; }
cp "$SCRIPT_DIR/health-audit-check.timer" "$SERVICE_DIR/health-audit-check.timer" || { echo "Failed to install health-audit-check.timer"; exit 1; }

# Reload systemd daemon
echo -e "${YELLOW}Reloading systemd daemon...${NC}"
systemctl daemon-reload || { echo "Failed to reload systemd"; exit 1; }

# Enable and start the timers
echo -e "${YELLOW}Enabling timers...${NC}"
systemctl enable health-audit.timer || { echo "Failed to enable health-audit.timer"; exit 1; }
systemctl enable health-audit-check.timer || { echo "Failed to enable health-audit-check.timer"; exit 1; }

echo -e "${YELLOW}Starting timers...${NC}"
systemctl start health-audit.timer || { echo "Failed to start health-audit.timer"; exit 1; }
systemctl start health-audit-check.timer || { echo "Failed to start health-audit-check.timer"; exit 1; }

# Show status
echo ""
echo "=========================================="
echo "Installation Complete!"
echo "=========================================="
echo ""
echo -e "${GREEN}Active Timers:${NC}"
systemctl list-timers health-audit.timer health-audit-check.timer
echo ""
echo -e "${GREEN}Service Status:${NC}"
systemctl status health-audit.timer --no-pager | head -n 5
echo ""
echo -e "${YELLOW}Next Steps:${NC}"
echo "1. Configure alert.env for email/Slack notifications (optional)"
echo "2. Monitor logs: journalctl -u health-audit.service -f"
echo "3. Check timer schedule: systemctl status health-audit.timer"
echo "4. Manually run audit: systemctl start health-audit.service"
echo "5. Check self-health: $SCRIPT_DIR/health_check.sh"
echo "6. Runner scripts installed in $BIN_DIR"
echo ""
