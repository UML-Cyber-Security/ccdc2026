# WinStride Risk Assessment

Open-source Windows security monitoring and SIGMA detection platform (agent + API + web UI). Used as our blue team SIEM during the event.

## Overview

**Functionality:** Windows endpoint telemetry collection (Security events, Sysmon, PowerShell, network, processes, autoruns) with 121 compiled SIGMA rules evaluated in the browser. Agent runs as a Windows service on each monitored host and reports to a central API over HTTP or mTLS HTTPS. SQLite backend, React frontend.

**Use Case During Event:** Primary SOC visibility — live event stream, SIGMA detections, logon graph, process trees, cross-module correlation (PowerShell ↔ Sysmon, Network ↔ Sysmon). Run API on a dedicated box (DC or SOC host), install agent on every Windows host we defend.

**Risk Assessment:** MEDIUM

## Component Risk Breakdown

### `WinStride-Agent/` (Windows service, .NET 8)
**Risk:** MEDIUM — Runs as `LocalSystem`. Reads Security/Sysmon/PowerShell event logs, enumerates TCP connections and processes, and ships them to the API. Requires agent → API network path open. If the agent's outbound destination is attacker-controlled (misconfigured `ServerAddress`), all endpoint telemetry leaks.

### `WinStride-Api/` (ASP.NET API, SQLite)
**Risk:** MEDIUM — Accepts telemetry ingest on configured port (default 5090 HTTP / 7097 HTTPS). HTTP mode has no auth; HTTPS mode enforces client cert (mTLS). Must be firewalled to the agent subnet only. SQLite DB contains full PowerShell script-block content including any credentials captured from red-team activity — treat the DB file as sensitive.

### `Winstride-Web/` (React frontend)
**Risk:** LOW — Static SPA, no server-side exec. Loads events from API and compiles SIGMA YAML client-side. Browser accessing the web UI needs network path to the API.

### `scripts/setup-winstride.ps1`
**Risk:** LOW — Prerequisite check + repo validation. Installs .NET SDK and Node.js with `-Auto`. Requires admin. No system config changes beyond package install.

### `scripts/setup-certs.ps1`
**Risk:** LOW — Generates self-signed server + client certs for mTLS. Writes PFX files to disk. Protect the PFX passwords.

### `scripts/install-run-agent.ps1`
**Risk:** MEDIUM — Publishes, installs, and starts the agent as a Windows service running as `LocalSystem`. Re-running replaces the existing service binary. Wrong `ServerAddress` value points the agent at a different host — verify before deploy.

### `scripts/setup-agent.ps1`, `scripts/start-winstride.ps1`
**Risk:** LOW — Wrapper scripts for agent config and launching API/web in dev mode.

### `scripts/ingest-evtx.ps1`
**Risk:** LOW — Parses local EVTX files and posts events to the API. Read-only against logs.

### `scripts/ensure-autoruns.ps1`
**Risk:** LOW — Downloads Sysinternals `autorunsc.exe` if missing. Outbound fetch from `live.sysinternals.com`; skip on air-gapped hosts.

### `deploy/docker-compose.yml`
**Risk:** LOW — Legacy Postgres compose file. Not used in the current SQLite-based deployment. Safe to ignore.

## Deployment Notes

- **Always use HTTPS/mTLS mode in competition.** HTTP mode is dev-only and unauthenticated.
- **Firewall the API port** to the monitored-host subnet. Web UI access from SOC workstation only.
- **Back up `winstride.db`** periodically — it's the detection history.
- Agent logs to Windows Event Log under source `WinStride-Agent`. Service name: `WinStrideAgent`.
- Red team script-block content is stored verbatim in the DB. Don't ship the DB off-host without scrubbing.
