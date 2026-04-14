# Sysinternal Files

## install_firefox.ps1
**Functionality:** Downloads and silently installs the latest Firefox browser from Mozilla's CDN.

**Use Case During Event:** Deploying a secure browser on Windows hosts for web-based management tasks.

**Risk Assessment:** LOW — No version pinning or checksum validation. Silent install suppresses error messages.

## install_nmap.ps1
**Functionality:** Downloads and silently installs Nmap 7.94 from nmap.org.

**Use Case During Event:** Deploying network scanning capability on Windows hosts for reconnaissance and service verification.

**Risk Assessment:** MEDIUM — Version pinned to outdated 7.94. No integrity check on downloaded binary. Nmap is a powerful reconnaissance tool.

## install_wireshark.ps1
**Functionality:** Downloads and silently installs Wireshark 4.6.4 from the Wireshark CDN.

**Use Case During Event:** Deploying packet capture capability for network traffic analysis and incident investigation.

**Risk Assessment:** MEDIUM — No integrity check on downloaded binary. Wireshark enables capture of all network traffic including plaintext credentials.
