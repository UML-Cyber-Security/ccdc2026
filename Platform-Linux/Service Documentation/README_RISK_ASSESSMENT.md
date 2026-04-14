This will outline the operations and risks of all scripts in this directory and its sub-directories.

Email directory:
Bash:

internal-db-dump.sh, internal-gen-bacup.sh, internal-web-backup.sh
This collection of scripts backs up important/custom service configuration files specified by the user and stores them on the machine that they are hosted in. No exfiltration of data is done, and services are backed up with secure permissions. 
RISK: Low - These scripts only backup and copy over service files. This should pose no risk to the environment. 

pii.sh
This script attempts to find "PII" data on the system, using simple find commands and regex expressions.
RISK: None - This script does not install or modify any system files

SendMailWrapper
Script simplifies the process of sending mail using the Sendmail Linux service.
RISK: None - This script does not install or modify any system files
