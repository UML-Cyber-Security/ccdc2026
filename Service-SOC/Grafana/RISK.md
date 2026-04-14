This md file contains a description of tools within the current directory

### loki.sh
Functionality/Description: Installs Grafana Loki v2.9.3 by downloading the binary, creating necessary directories, configuring a local logging instance, and setting it up as a systemd service listening on port 3100.

Use Case During Event: When the team needs to centralize and store logs from multiple sources for easier monitoring, searching, and analysis during incident response.

Risk Assessment: Medium – the script installs software from an external source and creates a persistent service. Additionally, improper network configuration or firewall rules could unintentionally expose the service, and log storage may grow quickly, potentially consuming disk space.

### prometheusGrafana.sh
Functionality/Description: Installs and configures Prometheus, Node Exporter, and Grafana by downloading binaries, setting up configuration files, creating systemd services, and enabling all services for system monitoring and visualization.

Use Case During Event: When the team needs real-time system monitoring, performance metrics, and dashboards to track system health, resource usage, and detect anomalies during an incident.

Risk Assessment: Medium – the script installs multiple services from external sources and exposes several web interfaces (ports 9090, 9100, and 3000). Default configurations (such as Grafana’s default credentials admin/admin) pose a security risk if not changed. Additionally, improper network configuration could expose these services externally. The script also creates persistent systemd services and runs binaries from the user’s home directory, which may introduce stability or security concerns if files are modified or tampered with.

### promtail.sh
Functionality/Description: Installs Promtail v2.9.3 by downloading the binary, configuring log collection from system log files and the systemd journal, and setting it up as a systemd service to forward logs to Grafana Loki.

Use Case During Event: When the team needs to collect and forward logs from local systems (e.g., syslog, auth logs, audit logs, and Sysmon logs) to a centralized logging server for monitoring and analysis.

Risk Assessment: Medium – the script installs and enables a persistent service that continuously reads sensitive log files (e.g., /var/log/auth.log, /var/log/audit/audit.log). If misconfigured, it could expose sensitive information or overwhelm the logging system. Additionally, logs are sent over HTTP without encryption (http://localhost:3100), which could be a risk if traffic is redirected or the service is exposed. Improper permissions or configuration could also lead to unauthorized access to logs.

### setup-linux-client.sh
Functionality/Description: Configures a Linux client to forward logs and metrics to a centralized SOC server by installing and configuring Node Exporter, Promtail, and Falco. The script sets up systemd services, configures log collection (including system, auth, audit, and Falco logs), and forwards data to a remote logging system.

Use Case During Event: When the team needs to quickly onboard multiple Linux machines into a centralized monitoring and logging infrastructure for visibility, detection, and incident response across the environment.

Risk Assessment: High – the script performs extensive system modifications, including installing multiple services, adding external repositories, importing GPG keys, and enabling persistent background services. It also transmits logs and system data over the network to a remote server, which could expose sensitive information if the destination is compromised or communication is not secured (uses HTTP, not HTTPS). Additionally, misconfiguration or incorrect input (e.g., wrong SOC server IP) could disrupt logging or leak data. The script requires root privileges and modifies critical system components, increasing the potential impact of misuse or errors.

### tls-setup.sh
Functionality/Description: Configures TLS encryption for Grafana by generating a self-signed local Certificate Authority (CA), creating SSL certificates for the Grafana server, and modifying Grafana configuration files to enable HTTPS access on the specified SOC server IP.

Use Case During Event: When the team needs to secure the Grafana web interface with HTTPS to protect dashboard access and prevent credential or data exposure during monitoring and incident response operations.

Risk Assessment: Medium – the script modifies critical Grafana configuration files and replaces the default HTTP setup with HTTPS using a self-signed certificate, which may cause service disruption if misconfigured. The use of self-signed certificates can trigger browser trust warnings and may not be suitable for production environments without proper certificate management. Additionally, incorrect IP input or configuration errors could result in Grafana becoming inaccessible until manually corrected.