This md file contains a description of tools within the current directory

## Sysmon Role
Functionality/Description: Installs Sysmon for Linux by adding the Microsoft package repository, deploying a configuration file, initializing Sysmon, and enabling the service for process and network activity monitoring.

Use Case During Event: When the team needs enhanced endpoint visibility, including process creation and network connections, to detect malicious behavior on Linux systems.

Risk Assessment: Medium – the role installs external packages from a third-party repository and enables a persistent monitoring service. There is a risk associated with trusting external repositories and potential performance overhead from logging. Misconfiguration could also result in excessive log generation.

### Auditd Role
Functionality/Description: Installs the auditd service and related plugins on Linux systems, deploys a custom audit rules file, and enables the audit daemon to provide system-level logging of security-relevant events.

Use Case During Event: When the team needs to enable detailed host-based logging to monitor privilege escalation, file access, and other suspicious activity across Linux systems.

Risk Assessment: Low – the role primarily installs and configures logging tools without modifying existing system behavior. However, improperly configured audit rules could generate excessive logs or impact system performance.

