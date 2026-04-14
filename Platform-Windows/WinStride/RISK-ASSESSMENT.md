# WinStride

Open-source Windows security monitoring and SIGMA detection platform. Agent + API + web UI, 121 compiled SIGMA rules, SQLite backend.

## WinStride-Agent/
**Functionality:** Windows service (.NET 8) running as `LocalSystem`. Collects Security/Sysmon/PowerShell event logs, enumerates TCP connections and running processes, and ships telemetry to the API over HTTP or mTLS HTTPS.

**Use Case During Event:** Installed on every defended Windows host to feed the SOC dashboard with live endpoint telemetry and SIGMA detections.

**Risk Assessment:** MEDIUM — Runs as `LocalSystem`. If `ServerAddress` is misconfigured or DNS is hijacked, all endpoint telemetry leaks to the attacker. Agent binary replacement on re-install means a compromised API host can push a trojaned agent to every endpoint.

## WinStride-Api/
**Functionality:** ASP.NET ingest API with SQLite backend. Accepts telemetry from agents on port 5090 (HTTP) or 7097 (HTTPS/mTLS). Stores events, autoruns, processes, and network connections in `winstride.db`.

**Use Case During Event:** Central collector running on a dedicated SOC host or DC. Aggregates all agent telemetry for the web UI to query.

**Risk Assessment:** HIGH — HTTP mode has no auth; HTTPS mode requires client cert (mTLS). Must be firewalled to the agent subnet only. Captures full PowerShell script-block content including any credentials surfaced by red-team activity — `winstride.db` is effectively a credential store until wiped.

## Winstride-Web/
**Functionality:** React SPA frontend. Compiles 121 SIGMA YAML rules client-side, queries the API for events, renders dashboards, logon graph, process trees, and cross-module correlation views.

**Use Case During Event:** SOC operator UI for triaging detections and pivoting through endpoint activity.

**Risk Assessment:** LOW — Static SPA, no server-side execution. Browser needs network path to the API. Do not expose the hosting origin beyond the SOC subnet.

## scripts/setup-winstride.ps1
**Functionality:** Installs .NET SDK and Node.js prerequisites, validates repo layout for the service-based install flow.

**Use Case During Event:** First-run bootstrap on a new API host before `setup-certs.ps1`.

**Risk Assessment:** LOW — Admin required. Package install only, no system config changes. `-Auto` installs without prompting.

## scripts/setup-certs.ps1
**Functionality:** Generates self-signed server and client certificates for mTLS, writes PFX files with user-supplied passwords.

**Use Case During Event:** One-time cert provisioning for the API and every agent before HTTPS rollout.

**Risk Assessment:** LOW — Self-signed only. PFX passwords are the only protection for the client certs; leaking a client PFX lets an attacker impersonate an agent.

## scripts/install-run-agent.ps1
**Functionality:** Publishes the agent project, writes the agent config, installs and starts the `WinStrideAgent` Windows service as `LocalSystem`. Supports HTTP and mTLS HTTPS modes.

**Use Case During Event:** Primary tool for deploying the agent to every Windows endpoint.

**Risk Assessment:** MEDIUM — Runs as `LocalSystem`. Re-running replaces the service binary without confirmation. Wrong `-ServerAddress` points the agent at a different host and silently leaks telemetry. PFX password is passed as a script parameter if not prompted.

## scripts/setup-agent.ps1
**Functionality:** Helper wrapper that configures the agent's `appsettings.json` (server address, port, cert paths) without installing the service.

**Use Case During Event:** Reconfiguring an already-installed agent without reinstalling.

**Risk Assessment:** LOW — Writes to agent config file only. No service changes.

## scripts/start-winstride.ps1
**Functionality:** Launches API and web in dev mode from source (no service install).

**Use Case During Event:** Local testing or quick-start SOC deployment when a full service install isn't needed.

**Risk Assessment:** LOW — Foreground dev-mode processes. Stops when the shell closes.

## scripts/ingest-evtx.ps1
**Functionality:** Parses local EVTX files and POSTs the events to the API.

**Use Case During Event:** Backfilling historical logs from a host that wasn't yet running the agent.

**Risk Assessment:** LOW — Read-only against EVTX files. Ingest load on the API proportional to file size.

## scripts/ensure-autoruns.ps1
**Functionality:** Checks for Sysinternals `autorunsc.exe` and downloads it from `live.sysinternals.com` if missing.

**Use Case During Event:** Ensures the agent's autoruns module has its dependency before startup.

**Risk Assessment:** LOW — Single outbound fetch from Microsoft. Skip on air-gapped hosts; pre-stage `autorunsc.exe` instead.

## deploy/docker-compose.yml
**Functionality:** Legacy Postgres compose file from the pre-SQLite era.

**Use Case During Event:** None. Not used by the current SQLite-based deployment.

**Risk Assessment:** LOW — Inert unless someone runs `docker compose up`. Left in tree for reference.
