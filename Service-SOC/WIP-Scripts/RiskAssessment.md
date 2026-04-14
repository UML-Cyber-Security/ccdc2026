## falco_fully_privileged_prom_loki.sh

**Functionality/Description:** Extends `fully-privilege-docker-install.sh` by additionally deploying a Promtail container alongside Falco, configured to scrape Falco's container logs and ship them to a central Loki instance. Falco is configured to emit JSON output for cleaner log ingestion, and Promtail is scoped to only collect logs from the Falco container. **Script is marked as WIP and untested.**

**Use Case During Event:** Use on machines where you want Falco alerts automatically forwarded to your Grafana/Loki stack without manually tailing container logs - replaces `fully-privilege-docker-install.sh` on hosts where log shipping is needed.

**Risk Assessment:** Medium - runs Falco in `--privileged` mode giving the container broad host kernel access, installs packages and starts services which may conflict on non-standard systems, and the `docker rm -f` step will forcefully remove any existing containers sharing the same names. Additionally, the Loki URL defaults to `http://loki:3100` and must be set correctly via the `LOKI_URL` environment variable before running, otherwise logs will silently fail to ship.