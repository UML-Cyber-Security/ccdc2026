# Logging

**Last Updated:** April 9, 2026

This directory contains playbooks used to install logging tools on Linux hosts. The following tools are installed:
- Sysmon for Linux
- Auditd

## Sysmon
This playbook installs Sysmon for Linux on Debian and RedHat family hosts.

## Auditd
This playbook installs the Auditd service on Debian and RedHat family hosts. It sets the following 10 rules:
- Monitor root privilege escalation via sudo
- Monitor file permission changes
- Monitor unauthorized file access
- Monitor passwd file changes
- Monitor shadow file changes
- Monitor sudoers file changes
- Monitor time changes
- Monitor file deletions
- Monitor login events
- Monitor `su` command usage
