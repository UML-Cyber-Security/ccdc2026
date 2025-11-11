Author: Ofir and Irakli\
How to install and AD & CA

### Install AD DS (GUI):
1. **Install the AD DS role**
    1. Open Server Manager
    2. Click Manage → Add Roles and Features
    3. Server Roles: check Active Directory Domain Services
        - When prompted, click Add Features
    4. Click Install

2. **Promote the server to a Domain Controller (new forest)**
    1. When the role is done installing, in Server Manager click the yellow flag
    2. Click Promote this server to a domain controller
    3. In Deployment Configuration:
        - For new environment: choose Add a new forest
        - Enter Root domain name (e.g. zodu.com)
    4. Domain Controller Options:
        - Choose Forest functional level and Domain functional level (Windows Server 2016 is the newest one)
        - Leave Domain Name System (DNS) server checked (if this will be DNS)
        - Set Directory Services Restore Mode (DSRM) password
    5. Let prerequisite check run → if no blocking errors, click Install 
    6. Server will reboot and come back as a domain controller for the new forest.

### install AD DS (PowerShell):
open PowerShell as administrator and run:
```powershell
Install-WindowsFeature AD-Domain-Services -IncludeManagementTools\
Install-ADDSForest `
    -DomainName "zodu.com" `
    -DomainNetbiosName "ZODU" `
    -InstallDNS `
    -SafeModeAdministratorPassword (ConvertTo-SecureString "1qazxsW@1" -AsPlainText -Force)`
    -ForestMode "Win2016" `
    -DomainMode "Win2016" `
    -Force
```
then reboot the machine

### CA installation (GUI):
Make sure to log on as Domain\Administrator
1. check if the CA is joined to the AD machine, if not join it.
2. Open Server Manager → click Manage → Add Roles and Features.
3. Select the local server → click Next.
4. Under Server Roles, select Active Directory Certificate Services.
	- Click Add Features when prompted.
5. When installation finishes, click Configure Active Directory Certificate Services on the destination server.
6. On Role Services, check Certification Authority (and optionally Certification Authority Web Enrollment - not required for CCDC but was nice when I tried it).
7. On Setup Type, choose: Enterprise CA
8. On CA Type, choose Root CA (first CA in hierarchy)
9. On Private Key, choose:
	- Create a new private key for a new CA
10. Choose cryptographic options (RSA 2048) → Next.
11. On CA Name, accept default (e.g., ZODU-CA) or customize.
12. On CA Database, leave defaults or specify custom paths → Next → Configure.
13. Verify the CA service is running:
	- Open Server Manager → Tools → Certification Authority
### Install CA (PowerShell):
Make sure to log on as Domain\Administrator\
open PowerShell as administrator and run:
```powershell
Install-WindowsFeature AD-Certificate -IncludeManagementTools 

Install-AdcsCertificationAuthority ` 
    -CAType EnterpriseRootCA ` 
    -CACommonName "ZODU for example" ` 
    -CryptoProviderName "RSA#Microsoft Software Key Storage Provider" ` 
    -KeyLength 2048 ` 
    -HashAlgorithmName SHA256 ` 
    -ValidityPeriod Years ` 
    -ValidityPeriodUnits 10 ` 
    -Force
```
