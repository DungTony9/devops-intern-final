# DevOps Intern Final Assessment — End-to-End NGINX Pipeline

![CI/CD Pipeline](https://github.com/DungTony9/devops-intern-final/actions/workflows/ci.yml/badge.svg)

* **Candidate Name:** Nguyen Viet Dung
* **Submission Date:** 2026-11-01
* **Repository:** `https://github.com/DungTony9/devops-intern-final`

---

## 1. Architecture Overview

This repository delivers a reproducible, end-to-end deployment and observability pipeline for a containerised NGINX web application. Every stage consumes the verified artefact of the preceding stage:

1. **Source Control (GitHub):** Feature-branch workflow with conventional commits and pull-request gating.
2. **Continuous Integration (GitHub Actions):** Runs static analysis (`ShellCheck` & `Hadolint`), builds a rootless Docker image injected with the commit `BUILD_SHA`, executes automated readiness checks via `healthcheck.sh`, and publishes verified images to GitHub Container Registry (`ghcr.io`).
3. **Orchestration (HashiCorp Nomad & Consul):** Pulls the pinned image from GHCR, enforces CPU/Memory quotas, registers the service in Consul with `/healthz` HTTP checks, and manages rolling updates with automatic revert.
4. **Log Aggregation (Grafana, Loki & Promtail):** Scrapes container logs and Nomad metadata labels via Docker service discovery, indexing streams in Loki for real-time LogQL querying in Grafana.

```text
+-------------------+      git push / PR      +---------------------------+
|   Developer Git   | ----------------------> |   GitHub Actions CI/CD    |
| (feature/* -> PR) |                         | (Lint -> Build -> Test)   |
+-------------------+                         +-------------+-------------+
                                                            |
                                                            | docker push (main)
                                                            v
+-------------------+     docker pull         +---------------------------+
|  HashiCorp Nomad  | <---------------------- | GitHub Container Registry |
|  & Consul Check   |                         | (ghcr.io/.../nginx-app)   |
+---------+---------+                         +---------------------------+
          |
          | stdout/stderr + Nomad labels
          v
+-------------------+      push streams       +---------------------------+
|     Promtail      | ----------------------> |   Grafana Loki & Explore  |
| (Docker SD Agent) |                         |   (LogQL Aggregation)     |
+-------------------+                         +---------------------------+
```

---

## 2. Prerequisites

Ensure the following tools are installed with versions matching or compatible with the pinned baseline below:

* **Docker Engine / Desktop:** `v27.x` (with Docker Compose `v2.x`)
* **HashiCorp Nomad:** `v1.9.x`
* **HashiCorp Consul:** `v1.20.x`
* **ShellCheck:** `v0.9.x`
* **Hadolint:** `v2.12.x`
* **OS Environment:** Linux (Ubuntu 22.04 LTS / WSL2 kernel `6.18.54.1-microsoft-standard-WSL2`)

---

## 3. Quick Start (Clone to Running Stack in 8 Commands)

Run the following commands from a clean machine to reproduce the entire application, orchestration, and monitoring stack:

```bash
# 1. Clone the repository and enter directory
git clone [https://github.com/DungTony9/devops-intern-final.git](https://github.com/DungTony9/devops-intern-final.git) && cd devops-intern-final

# 2. Verify host environment and scripts
./scripts/sysinfo.sh

# 3. Build the production NGINX image locally and tag for Nomad
docker build --build-arg BUILD_SHA=v1.0.0 -t ghcr.io/dungtony9/devops-intern-final/nginx-app:1.0.0 ./app

# 4. Start Consul and Nomad dev agents in the background
consul agent -dev > /tmp/consul.log 2>&1 &
sudo nomad agent -dev -bind 0.0.0.0 -network-interface='eth0' > /tmp/nomad.log 2>&1 &
sleep 5

# 5. Deploy the NGINX job to Nomad
nomad job run nomad/nginx-app.nomad.hcl

# 6. Start the Grafana + Loki + Promtail observability stack
docker compose -f monitoring/docker-compose.yaml up -d

# 7. Resolve the dynamic address allocated by Nomad and run healthcheck
NOMAD_ADDR=$(docker ps --filter "name=nginx-" --format "{{.Ports}}" | sed -E 's/(.*)->8080.*/\1/' | head -n 1)
./scripts/healthcheck.sh "http://${NOMAD_ADDR}/healthz"
```

---

## 4. Task-by-Task Implementation & Verification Output

### Task 1: Source Control
The project was developed incrementally on `feature/setup-nginx-app` using Conventional Commits (`chore:`, `feat:`, `fix:`, `ci:`, `docs:`), merged into `main` via a self-reviewed Pull Request, and tagged as `v1.0.0`.

```bash
git log --oneline --decorate --graph -n 8
```

---

### Task 2: Linux Scripting

Both scripts (`scripts/sysinfo.sh` and `scripts/healthcheck.sh`) use `#!/usr/bin/env bash`, enforce `set -euo pipefail`, pass `shellcheck` with zero warnings, and carry executable permissions in Git (`100755`).

**Command & Observed Output (`./scripts/sysinfo.sh`):**
```text
=== System Information ===
Current User : root (Effective UID: 0)
Host & Kernel: LAPTOP-Q7JVI83V / 6.18.54.1-microsoft-standard-WSL2
System Date  : 2026-11-01T08:48:03+07:00

--- Disk Usage ---
Filesystem      Size  Used Avail Use% Mounted on
/dev/sdf       1007G  6.6G  950G   1% /

--- Memory Usage ---
               total        used        free      shared  buff/cache   available
Mem:           3.7Gi       1.0Gi        75Mi        50Mi       2.7Gi       2.5Gi
Swap:          1.0Gi       0.0Ki       1.0Gi

--- Docker Daemon Status ---
Docker daemon is running.
```

**Command & Observed Output (`./scripts/healthcheck.sh`):**
```bash
./scripts/healthcheck.sh http://localhost:8080/healthz
```
```text
Checking health at: http://localhost:8080/healthz
[SUCCESS] Service is healthy (HTTP 200).
```

---

### Task 3: Containerisation

The image uses `nginx:1.27-alpine`, runs as the non-root `nginx` user on port `8080`, redirects temporary paths to `/tmp`, injects `BUILD_SHA` into both `index.html` and the `X-Build-SHA` HTTP header, and stays well under the 60 MB limit (`48.2MB`).

**Build & Run Commands:**
```bash
docker build --build-arg BUILD_SHA=test-123 -t nginx-assessment:1.0.0 ./app
docker images nginx-assessment:1.0.0
docker run -d --name test-nginx -p 8080:8080 nginx-assessment:1.0.0
```

**Observed Image Size (`docker images`):**
```text
IMAGE                    ID             DISK USAGE   CONTENT SIZE   EXTRA
nginx-assessment:1.0.0   8ea0410e0c7d       48.2MB             0B
```

**Observed Output (`curl -i http://localhost:8080/`):**
```text
HTTP/1.1 200 OK
Server: nginx/1.27.5
Date: Sun, 01 Nov 2026 01:57:16 GMT
Content-Type: text/html
Content-Length: 449
Last-Modified: Sun, 01 Nov 2026 01:56:24 GMT
Connection: keep-alive
ETag: "6ae69c48-1c1"
X-Build-SHA: test-123
Accept-Ranges: bytes

<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>DevOps Intern Final Assessment</title>
</head>
<body>
    <h1>Containerised NGINX Web Application</h1>
    <p><strong>Candidate Name:</strong> Viet Dung</p>
    <p><strong>Assessment Date:</strong> 2026-10-30</p>
    <p><strong>Build Identifier:</strong> test-123</p>
</body>
</html>
```

**Observed Output (`curl -i http://localhost:8080/healthz`):**
```text
HTTP/1.1 200 OK
Server: nginx/1.27.5
Date: Sun, 01 Nov 2026 01:57:57 GMT
Content-Type: application/octet-stream
Content-Length: 3
Connection: keep-alive
Content-Type: text/plain

OK
```

---

### Task 4: Continuous Integration

Defined in `.github/workflows/ci.yml` with four sequential jobs:
1. `lint`: Runs `shellcheck` on `scripts/*.sh` and `hadolint/hadolint-action@v3.1.0` on `app/Dockerfile`.
2. `build`: Builds the Docker image with `BUILD_SHA=${{ github.sha }}` and uploads the image tarball as a workflow artifact.
3. `test`: Loads the built image, starts the container, waits for readiness, and gates the pipeline using `./scripts/healthcheck.sh`.
4. `publish`: Runs only on `push` to `main`, authenticating to `ghcr.io` via `GITHUB_TOKEN` (`packages: write` least-privilege permission) and pushing `:latest` and `:${{ github.sha }}` tags.

---

### Task 5: Orchestration with Nomad

The job file `nomad/nginx-app.nomad.hcl` deploys `nginx-app` with `100 MHz` CPU and `64 MB` memory, dynamic host port mapping to container port `8080`, Consul HTTP health check on `/healthz`, rolling updates (`max_parallel = 1`, `auto_revert = true`), and `restart`/`reschedule` policies.

**Observed Output (`nomad job validate nomad/nginx-app.nomad.hcl`):**
```text
Job Warnings:
1 warning:

* group "web" defines services, but neither the group nor any of its tasks have shutdown_delay set

Job validation successful
```

**Observed Output (`nomad job plan nomad/nginx-app.nomad.hcl`):**
```text
+ Job: "nginx-app"
+ Task Group: "web" (1 create)
  + Task: "nginx" (forces create)

Scheduler dry-run:
- All tasks successfully allocated.

Job Modify Index: 0
```

**Observed Output (`nomad job run nomad/nginx-app.nomad.hcl`):**
```text
==> 2026-11-01T09:09:51+07:00: Monitoring evaluation "935236df"
    2026-11-01T09:09:51+07:00: Evaluation triggered by job "nginx-app"
    2026-11-01T09:09:51+07:00: Evaluation within deployment: "e608144e"
    2026-11-01T09:09:51+07:00: Allocation "8e064eb5" created: node "f396d7c6", group "web"
    2026-11-01T09:09:51+07:00: Evaluation status changed: "pending" -> "complete"
==> 2026-11-01T09:09:51+07:00: Evaluation "935236df" finished with status "complete"
==> 2026-11-01T09:09:51+07:00: Monitoring deployment "e608144e"
  ✓ Deployment "e608144e" successful
```

**Observed Output (`nomad job status nginx-app`):**
```text
ID            = nginx-app
Name          = nginx-app
Submit Date   = 2026-11-01T09:09:51+07:00
Type          = service
Priority      = 50
Datacenters   = dc1
Namespace     = default
Node Pool     = default
Status        = running

Summary
Task Group  Queued  Starting  Running  Failed  Complete  Lost  Unknown
web         0       0         1        0       0         0     0

Latest Deployment
ID          = e608144e
Status      = successful
Description = Deployment completed successfully

Deployed
Task Group  Auto Revert  Desired  Placed  Healthy  Unhealthy  Progress Deadline
web         true         1        1       1        0          2026-11-01T09:20:09+07:00

Allocations
ID        Node ID   Task Group  Version  Desired  Status   Created  Modified
8e064eb5  f396d7c6  web         0        run      running  31s ago  13s ago
```

---

### Task 6: Log Aggregation with Grafana Loki

Loki, Promtail, and Grafana are orchestrated via `monitoring/docker-compose.yaml` with committed configuration files (`loki-config.yaml` and `promtail-config.yaml`). Detailed setup notes and LogQL queries are documented in [monitoring/loki_setup.md](monitoring/loki_setup.md).

**Grafana Explore LogQL Verification (`{job="nginx-nomad-logs"} != " 200 "`):**

![Grafana Loki Explore Logs](docs/screenshots/grafana-loki-explore.png)

---

## 5. Troubleshooting (Actual Failures Encountered & Resolutions)

1. **Failure 1: Non-Root NGINX Container Crash on Startup (`emerg: open() "/var/run/nginx.pid" failed: Permission denied`)**
   * **Root Cause:** Running NGINX under the unprivileged `nginx` user prevented writing the PID file and temporary proxy buffers to `/var/run` and `/var/cache/nginx`.
   * **Fix:** Set `pid /tmp/nginx.pid;` and redirected `client_body_temp_path`, `proxy_temp_path`, `fastcgi_temp_path`, `uwsgi_temp_path`, and `scgi_temp_path` to `/tmp/` in `app/nginx.conf`, plus granted ownership of `/var/cache/nginx` and `/var/log/nginx` in `app/Dockerfile`.

2. **Failure 2: `curl: (7) Failed to connect to localhost port 28425: Connection refused` When Querying Nomad Dynamic Port**
   * **Root Cause:** On WSL2 Ubuntu, running `nomad agent -dev` bound the dynamically allocated port (`28425`) to the primary `eth0` bridge interface IP (`172.x.x.x`) rather than `127.0.0.1` (`localhost`).
   * **Fix:** Started the Nomad agent with `-bind 0.0.0.0 -network-interface='eth0'` and extracted the exact `IP:PORT` binding from `docker ps` to issue HTTP requests against the bound interface address.

3. **Failure 3: Windows CRLF Line Endings Triggering `ShellCheck` SC1017 Errors**
   * **Root Cause:** Creating shell scripts from a mounted Windows drive (`/mnt/e/...`) introduced `\r\n` carriage returns, causing POSIX execution and `ShellCheck` failures.
   * **Fix:** Converted all files to Unix `LF` line endings and enforced executable permissions directly in the Git index via `git update-index --chmod=+x`.

---

## 6. Known Limitations

* **Single-Node Dev Mode Orchestration:** Nomad and Consul are demonstrated using `-dev` agents without mTLS encryption, ACL tokens, or Raft multi-server consensus. In production, a 3-to-5 node Server cluster with ACL enforcement and Vault integration is required.
* **Ephemeral Local Loki Storage:** Loki uses local filesystem storage (`store: tsdb` on local disk) without retention compaction backed by object storage (e.g., AWS S3 or MinIO), meaning logs are tied to the single host lifecycle.
* **No TLS Termination or Ingress Controller:** Traffic reaches the dynamic Nomad host port directly over HTTP. With more time, an ingress reverse proxy (such as Traefik or NGINX with Let's Encrypt/Consul Connect service mesh) would be placed in front of the Nomad service to terminate TLS on port 443 and route traffic dynamically via Consul catalog discovery.