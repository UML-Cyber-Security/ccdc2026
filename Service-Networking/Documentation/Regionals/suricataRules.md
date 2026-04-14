# Recon / Lateral Movement
## Nmap NULL scan
`alert tcp any any -> $HOME_NET any (msg:"RECON Nmap NULL Scan"; flags:0; threshold:type threshold, track by_src, count 5, seconds 10; sid:1000060; rev:1;)`

## Nmap XMAS scan
`alert tcp any any -> $HOME_NET any (msg:"RECON Nmap XMAS Scan"; flags:FPU; threshold:type threshold, track by_src, count 5, seconds 10; sid:1000070; rev:1;)`

## TCP port sweep
`alert tcp any any -> $HOME_NET any (msg:"RECON TCP Port Sweep"; flags:S; threshold:type threshold, track by_src, count 20, seconds 5; sid:1000080; rev:1;)`

## LDAP enumeration (AD recon)
`alert tcp any any -> $HOME_NET 389 (msg:"RECON LDAP Enumeration Attempt"; threshold:type threshold, track by_src, count 50, seconds 10; sid:1000090; rev:1;)`

## SMB share enumeration
`alert tcp any any -> $HOME_NET 445 (msg:"RECON SMB Share Enumeration"; content:"|FF|SMB|72|"; threshold:type threshold, track by_src, count 10, seconds 5; sid:1000100; rev:1;)`

## PsExec lateral movement over SMB
`alert tcp any any -> $HOME_NET 445 (msg:"LATERAL MOVEMENT PsExec Pipe Detected"; content:"PSEXESVC"; nocase; sid:1000110; rev:1;)`

## WMI remote execution (135)
`alert tcp any any -> $HOME_NET 135 (msg:"LATERAL MOVEMENT WMI Remote Execution"; content:"IWbemServices"; nocase; sid:1000120; rev:1;)`

## Pass-the-hash indicator (NTLMSSP auth from unexpected source)
`alert tcp any any -> $HOME_NET 445 (msg:"CREDENTIAL Pass-the-Hash NTLMSSP Attempt"; content:"NTLMSSP"; content:"NTLMSSP_AUTH"; distance:0; threshold:type threshold, track by_src, count 5, seconds 10; sid:1000130; rev:1;)`

# C2 / Reverse Shells

## Netcat reverse shell
`alert tcp $HOME_NET any -> any any (msg:"C2 Possible Netcat Reverse Shell"; content:"/bin/sh"; nocase; content:"-e"; nocase; distance:0; within:10; sid:1000140; rev:1;)`

## PowerShell encoded command (common C2 stager)
`alert http $HOME_NET any -> any any (msg:"C2 PowerShell Encoded Command in HTTP"; content:"powershell"; nocase; content:"-enc"; nocase; distance:0; within:20; sid:1000150; rev:1;)`

## PowerShell download cradle
`alert http $HOME_NET any -> any any (msg:"C2 PowerShell DownloadString Cradle"; content:"DownloadString"; nocase; sid:1000160; rev:1;)`

## High-frequency DNS queries (tunneling/exfil)
`alert udp $HOME_NET any -> any 53 (msg:"C2 High Frequency DNS Queries Possible Tunnel"; threshold:type threshold, track by_src, count 100, seconds 10; sid:1000180; rev:1;)`

## Common Metasploit/C2 ports outbound
`alert tcp $HOME_NET any -> any 4444 (msg:"C2 Outbound Metasploit Default Port 4444"; sid:1000190; rev:1;)`
`alert tcp $HOME_NET any -> any 1234 (msg:"C2 Outbound Suspicious Port 1234"; sid:1000200; rev:1;)`
`alert tcp $HOME_NET any -> any 8888 (msg:"C2 Outbound Suspicious Port 8888"; sid:1000210; rev:1;)`

## Meterpreter over HTTPS (self-signed / no SNI)
`alert tls $HOME_NET any -> any 443 (msg:"C2 Possible Meterpreter TLS No SNI"; tls.sni; content:!""; sid:1000220; rev:1;)`

# Credential Attacks

## SSH brute force
`alert tcp any any -> $HOME_NET 22 (msg:"CREDENTIAL SSH Brute Force"; flags:S; threshold:type threshold, track by_src, count 6, seconds 30; sid:1000230; rev:1;)`

## RDP brute force
`alert tcp any any -> $HOME_NET 3389 (msg:"CREDENTIAL RDP Brute Force"; flags:S; threshold:type threshold, track by_src, count 6, seconds 30; sid:1000240; rev:1;)`

## FTP brute force
`alert tcp any any -> $HOME_NET 21 (msg:"CREDENTIAL FTP Brute Force"; content:"USER "; threshold:type threshold, track by_src, count 8, seconds 20; sid:1000250; rev:1;)`

## SMB auth brute force
`alert tcp any any -> $HOME_NET 445 (msg:"CREDENTIAL SMB Auth Brute Force"; content:"NTLMSSP"; threshold:type threshold, track by_src, count 8, seconds 20; sid:1000260; rev:1;)`

## Kerberoasting - excessive TGS requests
`alert udp $HOME_NET any -> $HOME_NET 88 (msg:"CREDENTIAL Kerberoasting TGS Enumeration"; threshold:type threshold, track by_src, count 20, seconds 10; sid:1000270; rev:1;)`

## AS-REP Roasting (Kerberos pre-auth disabled accounts probed)
`alert udp any any -> $HOME_NET 88 (msg:"CREDENTIAL AS-REP Roasting Attempt"; content:"|30|"; offset:0; depth:1; threshold:type threshold, track by_src, count 5, seconds 10; sid:1000280; rev:1;)`

# Web Attacks

## SQL injection in URI
`alert http any any -> $HOME_NET $HTTP_PORTS (msg:"WEB SQL Injection Attempt"; http.uri; pcre:"/(\%27|\'|--|\%23|#)/i"; sid:1000290; rev:1;)`

## Remote file inclusion
`alert http any any -> $HOME_NET $HTTP_PORTS (msg:"WEB Remote File Inclusion Attempt"; http.uri; content:"http://"; nocase; content:"=http"; nocase; distance:0; sid:1000310; rev:1;)`

## Web shell common filenames
`alert http any any -> $HOME_NET $HTTP_PORTS (msg:"WEB Possible Web Shell Access"; http.uri; pcre:"/(cmd|shell|c99|r57|wso|b374k|\.php\?cmd=)/i"; sid:1000320; rev:1;)`

## Directory traversal
`alert http any any -> $HOME_NET $HTTP_PORTS (msg:"WEB Directory Traversal Attempt"; http.uri; content:"../"; sid:1000330; rev:1;)`

# Normal Rulesets
```
alert tcp $HOME_NET any -> $EXTERNAL_NET any (msg:"Large outbound data transfer >1MB"; flow:established,to_server; stream_size:client,>,1048576; threshold:type limit, track by_src, count 1, sid:1000030; rev:1;)
alert tcp $HOME_NET any -> $EXTERNAL_NET any (msg:"Long-duration outbound connection"; flow:established,to_server; threshold:type limit, track by_src, count 1, seconds 3600; sid:1000040; rev:1;)
alert tcp $HOME_NET any -> $EXTERNAL_NET any (msg:"Rapid repeated connections - Possible beacons"; flow:to_server; threshold:type both, track by_src, count 5, seconds 60; sid:1000050; rev:1;)
```