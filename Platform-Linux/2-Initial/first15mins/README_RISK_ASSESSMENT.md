This will outline the operations and risks of all scripts in this directory and its sub-directories.

general-Linux
Files here are template files for Linux machine access and management. 
RISK: None

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