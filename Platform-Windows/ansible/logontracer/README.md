# LogonTracer

## run.sh
**Functionality:** Bash script scheduled via cron (every 30 min) that orchestrates AD log extraction, fetch, and ingestion into LogonTracer via Ansible playbooks.

**Use Case During Event:** Automated continuous ingestion of Windows security logs into LogonTracer for visual login analysis and anomaly detection.

**Risk Assessment:** MEDIUM — Log file grows indefinitely with no rotation. Silent failure if playbook path changes. Requires SSH key auth to all targets.

## site.yml
**Functionality:** Ansible entry point that imports the `extract_and_ingest.yml` operations playbook.

**Use Case During Event:** Running the full LogonTracer log pipeline manually or via cron.

**Risk Assessment:** LOW — Orchestrator only. Risk depends on the imported playbooks.

## setup/deploy_container.yml
**Functionality:** One-time setup that installs Docker, clones LogonTracer from GitHub, configures docker-compose, builds and starts containers. Aggressively cleans disk space.

**Use Case During Event:** Initial deployment of LogonTracer infrastructure on a Linux host for Windows log analysis.

**Risk Assessment:** HIGH — Removes apt cache and .git directory. Git clone without hash verification. 10-15 minute build can timeout. Docker state inconsistent if interrupted.

## setup/full_setup.yml
**Functionality:** Runs deploy_container.yml then setup_scheduling.yml sequentially to perform complete LogonTracer setup.

**Use Case During Event:** One-command full LogonTracer deployment including cron scheduling.

**Risk Assessment:** HIGH — If deploy fails partway, the scheduling cron may still be installed on an incomplete system.

## setup/setup_scheduling.yml
**Functionality:** Configures a cron job on the Ansible controller to run the log extraction/ingestion playbook at a configurable interval (default: every 30 min).

**Use Case During Event:** Automating recurring log collection so the team doesn't have to run it manually.

**Risk Assessment:** MEDIUM — No validation that run.sh exists before adding cron. Overlapping runs possible if playbook execution exceeds 30 minutes.

## operations/extract_and_ingest.yml
**Functionality:** Three-play workflow: export EVTX logs from Windows AD, fetch them to the Ansible controller, and ingest them into the LogonTracer container.

**Use Case During Event:** Core log pipeline that feeds Windows security events into LogonTracer for analysis.

**Risk Assessment:** MEDIUM — Cascading failure if any play fails. Large EVTX transfers may timeout. Assumes the LogonTracer container is already running.

## roles/deploy_container/tasks/main.yml
**Functionality:** Installs Docker, clones LogonTracer repo, configures docker-compose.yml, creates Docker network, builds containers, and cleans up disk space.

**Use Case During Event:** Backend task for LogonTracer container deployment.

**Risk Assessment:** HIGH — Aggressive cleanup of apt cache and temp files. Non-idempotent Docker network creation. Deleting .git prevents future repo updates.

## roles/extract_logs/tasks/main.yml
**Functionality:** Exports filtered Security and ForwardedEvents logs to EVTX files on Windows AD using wevtutil with configurable day filter.

**Use Case During Event:** Extracting Windows event logs from the domain controller for centralized analysis.

**Risk Assessment:** MEDIUM — Read-only on target. Day filter default of 0 means all history, which can produce very large files.

## roles/fetch_logs/tasks/main.yml
**Functionality:** Finds latest EVTX files on Windows AD and transfers them to the Ansible controller's temp directory.

**Use Case During Event:** Moving exported event logs from Windows to the Linux analysis host.

**Risk Assessment:** MEDIUM — Large EVTX transfers consume controller disk. Fails if no EVTX files exist from a prior extract.

## roles/ingest_logs/tasks/main.yml
**Functionality:** Copies EVTX files into the LogonTracer container, triggers Python ingestion into Neo4j, and cleans up temporary files.

**Use Case During Event:** Loading Windows event logs into LogonTracer's Neo4j database for graph-based login analysis.

**Risk Assessment:** HIGH — Deletes all EVTX files after ingestion with no backup if ingestion fails. Hardcoded container paths. 10-second startup pause may be insufficient.

## roles/setup_cron/tasks/main.yml
**Functionality:** Creates a cron job on the Ansible controller to run the LogonTracer playbook on a configurable schedule.

**Use Case During Event:** Setting up automated log collection without manual intervention.

**Risk Assessment:** MEDIUM — No pre-flight validation that run.sh exists. Cron user may lack Docker or SSH permissions. Orphaned cron entry if playbook directory moves.
