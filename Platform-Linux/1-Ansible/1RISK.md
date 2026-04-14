This will outline the operations and risks of all scripts in this directory and its sub-directories.

Enumeration
Scripts/Playbooks here just "enuerate" the target environment, logging any users, network traffic, processes, services, crons, keys, etc. 
RISK: Low - Since nothing is installed, except for Lin_Peas, and nothing else is modified on the systems, this scripts/playbooks should not pose any risk to the environment.

Incident-Response
Playbook here creates and configures admin accounts for the target Linux system, ensuring that they have admin permissions and have basic "hardening".
RISK: Low - Playbook should only create and configure a new Linux users, meaning that it should not pose any major risk to the environemnt.

create-accounts-copy-ssh-keys.yaml
Playbook here creates and configures admin accounts for the target Linux system, enabling key authentication.
RISK: Low - Playbook should only create and configure a new Linux users, meaning that it should not pose any major risk to the environemnt.