Default Agent Install sh
Description/Functionality:
A straightforward script that installs a Wazuh agent with default configuration on either a Debian or RPM-based Linux system. It prompts for the machine name and manager IP, adds the official Wazuh repo, and starts the agent service.
Use Case:
Meant for quick, clean installs where no custom configuration is needed — good for spinning up a new agent from scratch on a supported system. A solid starting point before layering on additional configs manually.
Risk:
Runs without a root check, so it will fail mid-execution if not run as superuser rather than catching it upfront. Only supports Debian and RPM, so running on SUSE or other distros will silently do nothing after prompting. No validation on the manager IP input either, which could cause a misconfigured agent that connects to the wrong host.

