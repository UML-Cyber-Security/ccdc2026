Least-Privilege-Docker_install
Description/Functionality:
Installs and runs Falco in Docker using selective Linux capabilities (SYS_PTRACE, NET_ADMIN, etc.) instead of full root access, dropping all others by default.
Use Case:
For teams following least-privilege principles who want Falco running without granting the container unrestricted host access. Supports a custom rules file via environment variable.
Risk:
The granted capabilities (SYS_ADMIN, NET_ADMIN, DAC_READ_SEARCH, etc.) combined with broad volume mounts like /proc and /dev still represent a meaningful attack surface. A compromised Falco container could leverage these to interfere with host processes or read sensitive system data. The least-privilege approach reduces risk compared to --privileged, but operators should audit which capabilities are truly necessary and treat this as a hardening step rather than a security guarantee.

Fully-Priviliege-Docker-Install.sh
Description/Functionality:
Installs and runs Falco in Docker with --privileged mode, handling Docker setup across Debian, RedHat, and SUSE distros. Interactively prompts the user to optionally mount a custom rules file.
Use Case:
The production-ready version for teams that need reliable runtime security monitoring without capability edge cases. The rules file prompt makes it easy to layer custom detections on top of Falco's defaults.
Risk:
--privileged grants the container near-unrestricted host access — a compromised container means a compromised host. The rules file path is taken from raw user input with only a basic existence check, so operators should be careful about what gets mounted.