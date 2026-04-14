This will outline the operations and risks of all scripts in this directory and its sub-directories.

Cron-Helper folder (cron-auth-user.sh & cron-setup-schedule.sh):
2 scripts that grant a user permissions to schedule  cron jobs and create a new user cronjob.
RISK: Low - There is no inherit risk with this script, unless a user adds a malicous crontjob to the machine.

Docker-Helper folder (docker-install.sh, firewall-docker.sh, inspect-all-containers.sh, install-editors.sh, post-install-scripts.sh, shell.sh):
Scripts in this folder install docker, add basic docker iptables rules, and allow for easier management of the docker service.
RISK: Low-Medium - None of scripts here pose any risk to the enviornemnt except for the firewall-docker.sh script which poses a medium risk. Since this script adds firewall rules to the system, there is a possibility for a service to break, although this can be easily reverted.

EasyRSA_CA (create-certificate.sh & setup-ca-server.sh):
Scripts here create a CA and .pem files. 
RISK: Low - These risk don't pose any risk to the environment.

File (suid.sh):
The script here scans the filesystem for any SUID binaries and allows for modification of any files found. 
RISK: Medium-High - The script allows for very easy modification of root owned files and binaries, which could break system operation and used improperlyl by the user. 

Firewall_Isolation (clean-isolation.sh & isolation.sh):
The scripts here setup and remove firewall "isolation" rules, essentially blocking out all traffic except for traffic used to access the machine. 
RISK: Medium-High - Even though these scripts are thouroughly tested, there is always a chance of locking out a user from the machine, or breaking some important system service that requires network traffic to funciton correctly. 

Gluster_Backup (cron-setup.sh, gluster-backup-inf.sh, gluster-backup.sh, multi-gluster-backup-inf.sh, multi-gluster-backup.sh):
These scripts implement a rotating backup system for Gluster "brick" directories suing "tar". 
RISK: Low-Medium - There is no inherit risk for any of these scripts, except for potential overfilling of system disk storage. 

Gluster_Setup (gluster-firewall.sh, gluster-install.sh, gluster-security.sh):
These scripts install and configure the GlusterFS cluster node, and allow for the implemenation of iptables rules compatable with the Gluster service.
RISK: Medium-High - Even though properly tested, iptables configuration has a chance of locking out users or breaking services. The service deployment itself does not pose any risk. 

Healthchecks (echo-coreservice.sh, log-coreservice.sh, setup-schedule.sh):
These scripts implement a very basic system hardening health-check framework, verifying that any critical services are running, , logging anomalies using "logger", validating auditd rule count and systeem kernel parameters using a cronjob. 
RISK: Low - These scripts install very basic services and should not pose any threat to the envioronment. 

IPTables-Helper (add-both.sh, filter_table_policies.sh, firewall-docker.sh, firewall-reset.sh, graylog.sh, k8s-basics.sh, list-table.sh, loop-port.sh, port-traffic.sh, ssh-non-standard-port.sh, trusted-ips.sh, wazuh.sh):
This collection of scripts implements a full firewall management toolkit for the Linux machines using iptables. This includes scripts that set default DROP/ACCEPT policies, add docker firewall chain rules, firewall flush and reset, IP whitelist generation, a wrapper script to help set custom rules, and SSH hardening by changing the default listening port. 
RISK: High - Although properly tested, these scripts have a chance of locking out remote user access or breaking service functionality. Unless a full lock out occurs, any changes made by these scripts can be easily reverted. 

Passwd-Policy (passwd-ppol.sh):
This script sets a basic, common sense password policy on local Linux systems through PAM.
RISK: Medium-High - This script modifies the Linux PAM authentication files which could potentially break system wide authentication. 

0-Initial-Backup.sh
Script creates a local system backup directory and backs up important system files
RISK: None - This script should not pose any risk to the environment since nothing is installed/moved. 

1-verify-pkgs.sh
Script verifies that all packages installed the OS are "original". 
RISK: None - This script does not install or modify anything on the system.

2-cron-allow.sh
Script restricts some permissions on cron and enables cron via systemd. 
RISK: Low - Script may unintentionally lock out non-root users from using cron, but can be easily reverted/fixed.

3-set-permisions.sh
Script sets "correct" secure file ownership permissions for important Linux files/directories.
RISK: Low - Script may unintentionally lock out non-root users from using cron or accessing other needed files but can be easily reverted/fixed.

4-install-firewall.sh
Script install and configures iptables persistence, disables firewalld, and enables the iptables service.
RISK: Medium - The script disables the firewalld service which could unintentially open up access to private services.

5-firewall-iptables.sh
Script sets up proper iptables firewall rules, hardening the system and protecting it against network based attacks. 
RISK: Medium-High - Script has a chance of locking out remote user access or breaking service functionality. Unless a full lock out occurs, any changes made by these scripts can be easily reverted. 

6-install-remove-service.sh
Script uninstalls Linux services which are very commonly used in malicous ways. 
RISK: Medium-High - Script uninstalls Linux services which could break functionality if the service was really required. 

7-auditd-isntall.sh
Script install and configures the auditd service with a custom ruleset.
RISL: Low - This script should not pose any risk to the environment except for eating up storage space on the machine due to logs. 

8-rsys.sh
Script install and configures the rsyslog service.
RISL: Low - This script should not pose any risk to the environment except for eating up storage space on the machine due to logs. 

9-journald.sh
Enables and configures the journald log service, integratin it with rsyslog.
RISK: Low - This script should not pose any risk to the environment except for eating up storage space on the machine due to logs. 

10-ssh-setup.sh
Script does very basic hardening of the SSHD service. This does not do anything extreme (like switching to public key authentication only).
RISK: Low-Medium - Altough nothing extreme is modifified, there is always a chance that the script will unintentionally lock out a system user. 

11-account.sh
Script creates custom "admin" accounts on the target system.
RISK: Low - This script should not pose any risk to the environemnt since it is only making new accounts and not installing/modifying any system files.

12-sudo.sh
This script appends sudo configuration via visudo, specifically enabling Defaults use_pty, and optionally supports redirecting sudo logs.
RISK: Low - Script modifies sudoers configuration in a non-atomic way using EDITOR="tee -a", which bypasses normal validation safeguards of visudo.

13-safesystemctl.sh
This script hardens a Linux system by writing kernel security settings into /etc/sysctl.d/ccdc.conf, applying them immediately, and enforcing additional runtime protections (ASLR, ptrace restrictions, AppArmor enforcement), while also disabling certain legacy/insecure services.
RISK: Medium - Script has some risk to the target system since it is directly modifying system kernel parameters. 

13-systemctl.sh
This script hardens a Linux system by writing kernel security settings into /etc/sysctl.d/ccdc.conf, applying them immediately, and enforcing additional runtime protections (ASLR, ptrace restrictions, AppArmor enforcement), while also disabling certain legacy/insecure services.
RISK: Medium - Script has some risk to the target system since it is directly modifying system kernel parameters. 

aide-setup.sh
This script installs and initializes AIDE (file integrity monitoring), builds its baseline database, and optionally configures a systemd timer or cron job to run periodic integrity checks.
RISK: Low - Has a chance of risk if the initial AIDE database is not clean or properly tuned,

list-suid-binary.sh
The script here scans the filesystem for any SUID binaries and allows for modification of any files found. 
RISK: Medium-High - The script allows for very easy modification of root owned files and binaries, which could break system operation and used improperlyl by the user. 

list-users.sh
Script lists Linux sytem users.
RISK: None - Nothing is installed or modified.

query-users.sh
Script lists out all Linux users with shell access and allows for instant modification of said user. 
Medium-High - Script allows for instant modification of any user which could lead to user lock out/deletion if used improperly.

remove-ldap.sh
Script removes the ldap service from the Linux machine.
RISK: Low - Script only uninstalls the ldap service, which could pose a risk if the service is needed on the machine for the infrastructure to function correctly. 

install.sh:
Script installs Docker, deploys the Nexterm container with a hardcoded encryption key, and registers an initial user account. The hardcoded `ENCRYPTION_KEY` in the docker run command is a notable security concern, as it is shared across all deployments using this script.
RISK: Medium — Docker installation and container deployment are generally safe, but the static encryption key means any attacker with access to the script or container data volume could decrypt stored credentials.

connect-ssh-interactive.sh:
Script interactively prompts the user to register SSH server entries and optionally store credentials (username/password) in the Nexterm instance via its API.
RISK: Low-Medium — The script itself is safe, but storing plaintext SSH credentials in Nexterm introduces risk if the Nexterm instance is compromised or improperly secured.

connect-ssh-file.sh:
Script bulk-imports SSH server entries into Nexterm by parsing a structured text file, optionally creating stored credential identities for each entry.
RISK: Low-Medium — Same credential storage risk as the interactive SSH script. Additionally, the input file may contain plaintext passwords, which poses a risk if the file is not properly secured or is left on disk after use.

connect-rdp-interactive.sh:
Script interactively prompts the user to register RDP server entries and optionally store credentials in the Nexterm instance via its API.
RISK: Low-Medium — Same concerns as the interactive SSH script. RDP credentials stored in Nexterm could be leveraged for lateral movement if the Nexterm instance is compromised.

onnect-rdp-file.sh: 
Script bulk-imports RDP server entries into Nexterm by parsing a structured text file, optionally creating stored credential identities for each entry.
RISK: Low-Medium — Same concerns as the file-based SSH script. Plaintext RDP credentials in the input file and Nexterm credential storage both represent a risk if access controls are not properly enforced.

