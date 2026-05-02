#!/bin/bash
# Uninstall script for systemd timer and service
# Run this with sudo to remove the health audit system service

set -e

SERVICE_DIR="/etc/systemd/system"
BIN_DIR="/usr/local/bin"

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "=========================================="
echo "Health Audit Systemd Uninstall"
echo "=========================================="

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}ERROR: This uninstall script must be run with sudo${NC}"
    exit 1
fi

read -p "Are you sure you want to uninstall the health audit timers? (y/N) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Uninstall cancelled."
    exit 0
fi

# Stop and disable timers
echo -e "${YELLOW}Stopping and disabling timers...${NC}"
systemctl stop health-audit.timer || true
systemctl stop health-audit-check.timer || true
systemctl disable health-audit.timer || true
systemctl disable health-audit-check.timer || true
echo -e "${GREEN} Timers stopped${NC}"

# Remove unit files
echo -e "${YELLOW}Removing unit files...${NC}"
rm -f "$SERVICE_DIR/health-audit.service"
rm -f "$SERVICE_DIR/health-audit.timer"
rm -f "$SERVICE_DIR/health-audit-check.service"
rm -f "$SERVICE_DIR/health-audit-check.timer"
rm -f "$BIN_DIR/health-audit-runner"
rm -f "$BIN_DIR/health-audit-check-runner"
echo -e "${GREEN} Unit files removed${NC}"

# Reload systemd daemon
echo -e "${YELLOW}Reloading systemd daemon...${NC}"
systemctl daemon-reload || true
echo -e "${GREEN} Daemon reloaded${NC}"

echo ""
echo "=========================================="
echo "Uninstall Complete!"
echo "=========================================="
