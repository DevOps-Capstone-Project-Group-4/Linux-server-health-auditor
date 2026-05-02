# ============================================================================
# Linux Server Health Auditor — Container Image
# ----------------------------------------------------------------------------
# Containerizes the team's health audit script. Designed to monitor the host
# system when run with --pid=host and host filesystems mounted read-only.
#
# Build (from repo root):
#   docker build -t health-auditor:latest -f docker/Dockerfile .
#
# Run once:
#   docker run --rm health-auditor:latest
#
# Run with logs persisted to host:
#   docker run --rm -v $(pwd)/logs:/opt/health-auditor/logs health-auditor:latest
# ============================================================================

FROM debian:12-slim

LABEL org.opencontainers.image.title="Linux Server Health Auditor"
LABEL org.opencontainers.image.description="Bash-based system health auditor: CPU, memory, and disk threshold checks with JSON output and Prometheus metrics"
LABEL org.opencontainers.image.source="https://github.com/DevOps-Capstone-Project-Group-4/Linux-server-health-auditor"
LABEL org.opencontainers.image.licenses="MIT"

# Install only what the audit scripts need:
#   bash       — script interpreter
#   coreutils  — df, tail, tr, stat, date
#   procps     — uptime, free
#   awk (gawk) — used in get_memory()
# Clean apt caches in the same RUN so they don't bloat the layer.
RUN apt-get update && apt-get install -y --no-install-recommends \
        bash \
        coreutils \
        procps \
        gawk \
        ca-certificates \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Working directory
WORKDIR /opt/health-auditor

# Create directories first so we can copy into them
RUN mkdir -p /opt/health-auditor/logs /opt/health-auditor/health-audit-files

# Copy both scripts and the threshold config so the image works whether you
# run check.sh (root) or health_audit.sh (from health-audit-files/).
# Two copies of threshold.env: one at root (for check.sh) and one in
# health-audit-files/ (for health_audit.sh which uses an absolute path).
COPY check.sh /opt/health-auditor/check.sh
COPY health-audit-files/health_audit.sh /opt/health-auditor/health-audit-files/health_audit.sh
COPY health-audit-files/threshold.env /opt/health-auditor/threshold.env
COPY health-audit-files/threshold.env /opt/health-auditor/health-audit-files/threshold.env

# Make scripts executable
RUN chmod +x /opt/health-auditor/check.sh /opt/health-auditor/health-audit-files/health_audit.sh \
    && ln -s /opt/health-auditor/health-audit-files/health_audit.sh /opt/health-auditor/health_audit.sh

# Healthcheck: container is healthy if /proc is readable.
HEALTHCHECK --interval=5m --timeout=10s --start-period=5s --retries=3 \
  CMD test -r /proc/loadavg || exit 1

# Default: run health_audit.sh (the more complete script with Prometheus output)
# Override with: docker run health-auditor:latest /opt/health-auditor/check.sh
ENTRYPOINT ["/bin/bash"]
CMD ["/opt/health-auditor/health_audit.sh"]
