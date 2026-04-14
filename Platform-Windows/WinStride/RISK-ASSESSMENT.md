# WinStride

Open-source Windows monitoring and SIGMA detection platform. Passive collector — reads Windows event sources that are already enabled (Security log, Sysmon, PowerShell ScriptBlock logging) and forwards them to a local API for display in a web UI. Makes no registry, GPO, audit policy, or system configuration changes.

## WinStride-Agent/
**Functionality:** Windows service (.NET 8). Reads existing Windows event channels (`Security`, `Microsoft-Windows-Sysmon/Operational`, `Microsoft-Windows-PowerShell/Operational`) via the standard EventLog API, enumerates current TCP connections and running processes via documented Win32 calls, and POSTs the data to the API over HTTP or mTLS HTTPS.

**Use Case During Event:** Installed on every defended Windows host so the SOC can see endpoint activity in one place.

**Risk Assessment:** LOW — Read-only collector. Does not modify the registry, audit policy, GPOs, or any system setting. Does not install drivers or hook the kernel. Consumes existing event channels through documented APIs, the same way Event Viewer does. Outbound network only (to the API host); opens no listening ports on the endpoint.

## WinStride-Api/
**Functionality:** ASP.NET ingest API with a local SQLite database file (`winstride.db`). Listens on **port 5090** (HTTP) or **port 7097** (HTTPS with mTLS client-cert auth) for agent telemetry. Stores events in the SQLite file for the web UI to query.

**Use Case During Event:** Central collector running on a dedicated SOC host. Aggregates agent telemetry for the web UI.

**Risk Assessment:** LOW — Single self-contained process; database is a file, not a server. Opens only the two ports above and only on the SOC host. HTTPS mode requires a client certificate (mTLS) so only provisioned agents can submit data. Recommended deployment: firewall the API ports to the agent subnet. Note: PowerShell ScriptBlock content is stored in the SQLite file like in any SIEM, so the SOC host should be access-controlled.

## Winstride-Web/
**Functionality:** React single-page app. Loads in a browser, queries the API for events, and renders dashboards. SIGMA rules are evaluated client-side in the browser tab.

**Use Case During Event:** SOC operator UI for triaging events.

**Risk Assessment:** MINIMAL — Static SPA. No server-side execution and no system access. Browser only needs a network path to the API.

## scripts/setup-winstride.ps1
**Functionality:** Installs .NET SDK and Node.js prerequisites on the SOC host and validates the repo layout.

**Use Case During Event:** First-run bootstrap on a new API host.

**Risk Assessment:** LOW — Installs runtime packages on the SOC host only. Does not touch endpoints. No registry, audit, or policy changes.

## scripts/setup-certs.ps1
**Functionality:** Generates self-signed server and client certificates for the optional mTLS mode and writes PFX files protected by user-supplied passwords.

**Use Case During Event:** One-time cert provisioning before HTTPS rollout.

**Risk Assessment:** MINIMAL — Generates files in the repo directory. Does not install certificates into Windows trust stores or modify system cert state.

## scripts/install-run-agent.ps1
**Functionality:** Publishes the agent project, writes the agent's `appsettings.json`, and registers/starts a Windows service named `WinStrideAgent` running as `LocalSystem` so it can read the Security event log.

**Use Case During Event:** Deploys the agent to a Windows endpoint.

**Risk Assessment:** LOW — Adds one Windows service. The service runs `LocalSystem` because reading the Security event log requires it (same requirement as Sysmon, Windows Defender, and any other event-log consumer). No registry edits beyond the standard service registration, no audit policy changes, no GPO changes. Re-running the script reinstalls the service binary, so restrict who can run it.

## scripts/setup-agent.ps1
**Functionality:** Edits the agent's `appsettings.json` (server address, port, cert paths) without touching the service.

**Use Case During Event:** Reconfiguring an installed agent.

**Risk Assessment:** MINIMAL — Writes one config file in the agent install directory.

## scripts/start-winstride.ps1
**Functionality:** Launches the API and web UI from source in dev mode (foreground processes, no service install).

**Use Case During Event:** Local testing or quick-start SOC deployment.

**Risk Assessment:** MINIMAL — Foreground processes that exit when the shell closes. No persistent install, no system changes.

## scripts/ingest-evtx.ps1
**Functionality:** Reads local `.evtx` files and POSTs the parsed events to the API.

**Use Case During Event:** Backfilling historical logs from a host that wasn't yet running the agent.

**Risk Assessment:** MINIMAL — Read-only against the supplied EVTX files. Touches no system state.

## scripts/ensure-autoruns.ps1
**Functionality:** Checks for Sysinternals `autorunsc.exe` and downloads it from `live.sysinternals.com` if missing, so the agent's autoruns view has its data source.

**Use Case During Event:** Pre-flight check before agent startup.

**Risk Assessment:** MINIMAL — One outbound HTTPS fetch from Microsoft. Drops a single signed Sysinternals binary in the agent directory. Skip on air-gapped hosts by pre-staging the file.

## deploy/docker-compose.yml
**Functionality:** Unused Postgres compose file from a previous architecture (current build uses SQLite).

**Use Case During Event:** None.

**Risk Assessment:** MINIMAL — Inert file. Does nothing unless someone manually runs `docker compose up`.
