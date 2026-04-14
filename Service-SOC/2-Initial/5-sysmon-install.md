# Sysmon for Linux Installation Script

**Author:** Michael Leahy  
**Last Updated:** March 8, 2026

## Overview

This Bash script installs and configures Sysmon for Linux on supported Linux distributions. Sysmon is a system monitoring utility developed by Microsoft that provides detailed event logging for system activity, helping administrators detect suspicious behavior and investigate security incidents.

The script performs the following actions:  

- Detects the operating system
- Installs the Microsoft package repository
- Installs Sysmon for Linux
- Creates a basic Sysmon configuration file
- Initializes Sysmon with the configuration
- Enables and starts the Sysmon service

The script supports both Debian-based and RHEL-based systems.

The script must be run with root privileges.

## Supported Operating Systems
This script currently supports:
### Debian-Based
- Debian
- Ubuntu
### RHEL-Based
- Red Hat Enterprise Linux
- Rocky Linux
- AlmaLinux
- CentOS

## Usage
    ```bash
    sudo ./sysmon-install.sh
    ```
