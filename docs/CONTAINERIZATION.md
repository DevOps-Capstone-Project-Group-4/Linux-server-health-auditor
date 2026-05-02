# Containerization Guide
**Project:** Linux Server Health Auditor
**Audience:** Anyone deploying or grading the containerized version
**Last updated:** 2026-05-02

---

## 1. Why containerize this?

Our health auditor is a Bash script that reads from `/proc`, runs `df` and `free`, and applies thresholds. It works fine on bare Linux. So why containerize?

Three reasons. First, **reproducibility** — the container guarantees the script runs against a known set of `bash`, `coreutils`, `procps`, and `gawk` versions on every host, regardless of what's installed on the host itself. Second, **deployment portability** — the same image runs unchanged on a developer's laptop, a Linux server, an EC2 instance, or as a container in ECS/EKS. Third, **clean integration with the Prometheus monitoring** — our README already describes running Prometheus in Docker; containerizing the auditor lets both pieces sit in the same compose file.

A note on the tradeoff: a container by default sees only its own processes and filesystem, which is the *opposite* of what a host monitoring tool wants. We solve this by running with `--pid=host` so the container sees the host's processes, and (optionally) mounting host paths read-only so it can see disk usage of the actual host. The container is a packaging layer, not a security boundary in this case.

## 2. What's in the image

The Dockerfile starts from `debian:12-slim` (~75 MB) and installs only what `check.sh` and `health_audit.sh` actually call: `bash`, `coreutils` (for `df`, `tail`, `tr`, `stat`, `date`), `procps` (for memory utilities), `gawk` (for `awk` parsing of `/proc/meminfo`), and `ca-certificates`. The final image is around 95 MB.

Both scripts are copied into `/opt/health-auditor/`, along with `threshold.env` so the configurable thresholds work. The default `CMD` runs `health_audit.sh` (which produces JSON + Prometheus metrics output). To run `check.sh` instead, override the command at run time.

A `HEALTHCHECK` confirms `/proc/loadavg` is readable — a lightweight liveness probe.

## 3. Running it

### One-shot run (from the repo root)

```bash
docker build -t health-auditor:latest -f docker/Dockerfile .
docker run --rm health-auditor:latest
```

This runs `health_audit.sh` once and exits. You'll see the JSON output and the threshold debug lines printed to your terminal.

### With logs persisted to the host

```bash
mkdir -p logs metrics
docker run --rm \
  -v $(pwd)/logs:/opt/health-auditor/logs \
  -v $(pwd)/metrics:/opt/health-auditor/health-audit-files \
  health-auditor:latest
```

After running, check `metrics/metrics.prom` — that's the Prometheus-format file the script generates.

### Continuous mode via docker compose

```bash
docker compose -f docker/docker-compose.yml up -d
docker compose -f docker/docker-compose.yml logs -f
```

The compose file runs the script every 5 minutes in a loop.

### Run check.sh instead of health_audit.sh

```bash
docker run --rm --entrypoint /bin/bash health-auditor:latest /opt/health-auditor/check.sh
```

### Override thresholds at runtime

```bash
docker run --rm \
  -e CPU_WARN=60 -e CPU_CRIT=80 \
  -e MEM_WARN=70 -e MEM_CRIT=85 \
  -e DISK_WARN=70 -e DISK_CRIT=85 \
  health-auditor:latest
```

## 4. How to verify it actually works — `verify-container.sh`

This is the answer to "how do I know the containerization is working." Run from the repo root:

```bash
./docker/verify-container.sh
```

The script prints a green ✓ PASS or red ✗ FAIL for each step and exits non-zero if anything fails — making it a drop-in CI test.

What gets checked:

- Docker is installed and the daemon is running
- The image builds without errors
- The image is under 200 MB
- The image declares a `HEALTHCHECK` and OCI labels
- A one-shot run produces output without crashing
- The output contains `timestamp`, `cpu`, `memory`, and `disk` sections
- The output contains threshold values
- The embedded JSON is valid
- The alternate `check.sh` entrypoint also runs successfully

The full container output is printed during verification, so you have visible evidence the script ran.

## 5. CI integration

The workflow at `.github/workflows/docker.yml` runs the verification script on every push and pull request. GitHub-hosted runners come with Docker pre-installed, so no extra setup is needed. End-to-end runtime is about 3 minutes.

The green checkmark on the repo's main page is the public proof that containerization works on a clean machine.

## 6. AWS deployment notes

The same image runs unchanged on EC2. Two production patterns:

**EC2 + Docker** (simpler): bake the image into a custom AMI or pull from ECR on first boot. Run via the host's cron pattern. The CloudWatch Agent on the host picks up the JSON output from the mounted log volume and ships it to CloudWatch Logs.

**ECS/Fargate** (cluster-native): push to ECR, define a scheduled task via EventBridge. Note: Fargate doesn't allow `--pid=host` or hostPath mounts, so this monitors the task's environment, not a host. For host auditing on AWS, EC2 + Docker is the right choice.

## 7. Common pitfalls

| Symptom | Cause | Fix |
|---|---|---|
| `permission denied` running verify script | Script needs execute bit | `chmod +x docker/verify-container.sh check.sh health-audit-files/health_audit.sh` |
| Build fails: `COPY check.sh ... not found` | Building from wrong directory | Run from repo root, not from `docker/` |
| Container reports 0% CPU and very low memory | Container only sees its own resources | Add `--pid=host` to see host processes |
| Logs disappear after container exits | Logs written inside container, not mounted | Add `-v $(pwd)/logs:/opt/health-auditor/logs` |
| `awk: command not found` during build | Docker base image stripped down | The Dockerfile installs `gawk` — confirm the apt-install step ran successfully |

## 8. Change log

| Date | Author | Change |
|---|---|---|
| 2026-05-02 | Docs Team | Initial containerization documentation, fitted to the team's check.sh and health_audit.sh |
