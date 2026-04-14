This will outline the operations and risks of all scripts in this directory and its sub-directories.

Email directory:
Bash:

external-db-dump.sh, external-gen-backup.sh, internal-db-dump.sh, internal-gen-bacup.sh, internal-web-backup.sh
This collection of scripts backs up important/custom service configuration files specified by the user and stores them either on the target or users local machine. 
RISK: Low - These scripts only backup and copy over service files. No risk should be present

pii.sh
This script attempts to find "PII" data on the system. 
RISK: None - This script does not install or modify any system files

SendMailWrapper
Script simplifies the process of sending mail using the Sendmail Linux service.
RISK: None - This script does not install or modify any system files