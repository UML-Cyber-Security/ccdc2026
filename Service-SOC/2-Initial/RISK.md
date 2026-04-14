This md file contains a description of tools within the current directory

### 0-Initial-Backup.sh
Functionality/Description: Backsup important files and directories to a newly create `/backups` directory. 

Use Case During Event: When the team needs to backup important files from a system before making changes. Can be used to compare different versions to see what has changed or why things no longer work

Risk Assessment: Low - the script only makes copies of files and directories, it doesn't change any existing files.

### 1-Init-Audit.sh
Functionality/Description: Gathers and outputs infromation about the machine, users and groups, network configuration, services, and potential malware or backdoors.

Use Case During Event: When the team needs to quickly gather information about a system for an initial assessment.

Risk Assessment: Low - the script only gather information about the file. It doesn't change any files or install any services.

### 2-ufw-firewall-setup.sh
Functionality/Description: The script installs UFW, sets basic default rules, disables Firewalld if active, and enables the UFW firewall. This script sets default deny for incoming and default allow outgoing traffic.  

Use Case During Event: When the team needs to quickly setup a basic host based firewall on Linux systems.

Risk Assessment: High - the script installs and enables a firewall. There is the possiblity of locking oneself out of the system if incorrect rules are set.  


### 3-Auditd-Install.sh
Functionality/Description: The script installs the audited service, sets custom rules, then enables the service

Use Case During Event: When the team needs to setup logging on Linux machines

Risk Assessment: Low - the script only installs Auditd logging tools, it doesn't change any existing files.

### 4-sshd-config-hardening.sh
Functionality/Description: The scripts hardens the SSH configuration file and sets secure values for necessary fields.

Use Case During Event: When the team needs to secure SSH access.

Risk Assessment: Medium - the script replaces the entire default SSH config file, but it creates a backup of the original file and doesn't set changes unless the `sshd -t` test passes

### 5-sysmon-install.sh
Functionality/Description: The script installs `sysmonforlinux`, creates the config file, and starts the Sysmon service

Use Case During Event: When the team needs to setup logging on Linux machines

Risk Assessment: Low - the script only installs Sysmon logging tools, it doesn't change any existing files.

### 6-user-creation.sh
Functionality/Description: The script creates user accounts with ssh access and keys, full sudo access, and sets up a home directory for each user.

Use Case During Event: When the team members need their own user accounts on a system so actions can easibly be attributed to them.

Risk Assessment: Medium - the script creates user accounts with full sudo access, which could be a risk if the accounts are not properly secured or if the keys are compromised.

### enum_users.sh
Functionality/Description: Enumerates all interactive user accounts on the system (UID >= 1000) plus root, writes them to users.txt with a numbered list. Overwrites the file on each run.

Use Case During Event: Run at the start of a round to get a clear picture of all user accounts on a machine before hardening.

Risk Assessment: Low - read-only operation, no passwords involved, no system changes made.

### change_passwords.
Functionality/Description: Prompts for a master hash, then derives a unique password for every interactive user and root using SHA-256 with the master hash and username as a seed. Skips blackteam accounts. Uses pw on FreeBSD and chpasswd on Linux distros.

Use Case During Event: Run immediately after enumeration to lock down all accounts and kick red team out of any pre-planted credentials.

Risk Assessment: Medium - changing passwords on service accounts could break services. Script mitigates this by filtering UID < 1000 and nologin/false shells, but verify before running on production services.

### recover_password.
Functionality/Description: Prompts for the master hash and a username, derives and displays that user's plaintext password.

Use Case During Event: Use mid-round when you need to recover a specific user's password without rerunning the full change script.

Risk Assessment: Low - derived password briefly appears in plaintext on the terminal, so be mindful of who has visibility of your screen.
