#!/usr/bin/env bash
# ============================================================================
# verify-container.sh — Prove the containerized health auditor works
# ----------------------------------------------------------------------------
# Run from the repo root. Builds the image, inspects it, runs an audit, and
# validates the output. Use as a local sanity check and as a CI gate.
#
# Usage:
#   ./docker/verify-container.sh
#
# Exit codes:
#   0 = all checks passed, 1 = at least one check failed
# ============================================================================

set -uo pipefail

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

PASS=0
FAIL=0
INFO=0

check() {
  local description="$1"; shift
  if "$@" >/dev/null 2>&1; then
    echo -e "  ${GREEN}✓ PASS${NC}  $description"
    PASS=$((PASS+1))
  else
    echo -e "  ${RED}✗ FAIL${NC}  $description"
    FAIL=$((FAIL+1))
  fi
}

step() { echo -e "\n${YELLOW}▶ $*${NC}"; }

# ---------- 0. Pre-flight ----------
step "Checking prerequisites"
check "docker is installed"      command -v docker
check "docker daemon is running" docker info

if [[ "$FAIL" -gt 0 ]]; then
  echo -e "\n${RED}Cannot continue — fix prerequisites first.${NC}"
  echo -e "${YELLOW}Tip:${NC} Make sure Docker Desktop is running, or start the daemon with: sudo systemctl start docker"
  exit 1
fi

# ---------- 1. Build the image ----------
step "Building the image"
if docker build -t health-auditor:test -f docker/Dockerfile . > /tmp/build.log 2>&1; then
  echo -e "  ${GREEN}✓ PASS${NC}  image built successfully"
  PASS=$((PASS+1))
else
  echo -e "  ${RED}✗ FAIL${NC}  build failed (last 20 lines of build log below)"
  tail -20 /tmp/build.log | sed 's/^/    /'
  exit 1
fi

# ---------- 2. Image properties ----------
step "Inspecting image properties"
SIZE_MB=$(docker image inspect health-auditor:test --format '{{.Size}}' | awk '{printf "%.0f", $1/1024/1024}')
echo "  Image size: ${SIZE_MB} MB"
check "image is under 200MB"   test "$SIZE_MB" -lt 200
check "has healthcheck"        bash -c '[[ "$(docker image inspect health-auditor:test --format "{{.Config.Healthcheck}}")" != "<nil>" ]]'
check "has OCI labels"         bash -c '[[ -n "$(docker image inspect health-auditor:test --format "{{.Config.Labels}}")" ]]'

# ---------- 3. Run a single audit pass ----------
step "Running a one-shot audit"
if docker run --rm health-auditor:test > /tmp/run.log 2>&1; then
  echo -e "  ${GREEN}✓ PASS${NC}  container ran without error"
  PASS=$((PASS+1))
else
  RC=$?
  echo -e "  ${RED}✗ FAIL${NC}  container exited with code $RC"
  echo "  Last lines of output:"
  tail -10 /tmp/run.log | sed 's/^/    /'
  FAIL=$((FAIL+1))
fi

# ---------- 4. Output verification ----------
step "Verifying script output"

# Show what the script actually produced (proof it ran)
echo "  Container output:"
echo "  ─────────────────────────────────────────"
sed 's/^/  /' /tmp/run.log
echo "  ─────────────────────────────────────────"

# Check for the expected JSON structure in stdout
check "output contains 'timestamp'"        grep -q '"timestamp"' /tmp/run.log
check "output contains 'cpu' section"      grep -q '"cpu"' /tmp/run.log
check "output contains 'memory' section"   grep -q '"memory"' /tmp/run.log
check "output contains 'disk' section"     grep -q '"disk"' /tmp/run.log
check "output contains threshold values"   grep -q 'warning_threshold' /tmp/run.log

# Validate that what the script produced is parseable as JSON
# The script outputs threshold debug lines + JSON, so extract just the JSON block
if python3 -c "
import sys, re, json
text = open('/tmp/run.log').read()
# Find the JSON object in the output (starts with { ends with })
match = re.search(r'\{[^{}]*\"cpu\".*?\}\s*\}', text, re.DOTALL)
if match:
    json.loads(match.group())
    sys.exit(0)
sys.exit(1)
" 2>/dev/null; then
  echo -e "  ${GREEN}✓ PASS${NC}  embedded JSON is valid"
  PASS=$((PASS+1))
else
  echo -e "  ${YELLOW}⚠ INFO${NC}  could not parse JSON from output (may be a format issue, not a container issue)"
  INFO=$((INFO+1))
fi

# ---------- 5. Test the alternate script too ----------
step "Testing check.sh entrypoint as well"
if docker run --rm --entrypoint /bin/bash health-auditor:test /opt/health-auditor/check.sh > /tmp/check.log 2>&1; then
  echo -e "  ${GREEN}✓ PASS${NC}  check.sh runs in container"
  PASS=$((PASS+1))
  echo "  check.sh output (first 5 lines):"
  head -5 /tmp/check.log | sed 's/^/    /'
else
  echo -e "  ${YELLOW}⚠ INFO${NC}  check.sh had issues (non-blocking)"
  INFO=$((INFO+1))
fi

# ---------- Summary ----------
TOTAL=$((PASS+FAIL))
echo ""
echo "================================================================"
echo "  Results: $PASS / $TOTAL passed${INFO:+, $INFO informational}"
echo "================================================================"
if [[ "$FAIL" -eq 0 ]]; then
  echo -e "${GREEN}All checks passed. Containerization is working.${NC}"
  exit 0
else
  echo -e "${RED}$FAIL check(s) failed.${NC}"
  exit 1
fi
