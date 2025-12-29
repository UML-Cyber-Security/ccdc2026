# How to request, issue, and export certificates with templates
Authors: Ofir and Irakli\
How to request, issue, and export certificates with templates

## Create a .inf file:
> [!IMPORTANT]
> Do the following on a domain-joined Windows machine

Create a file {NAME}.inf and write:
```
[Version]
Signature="$Windows NT$"

[NewRequest]
Subject = "CN={DNS ENTRY FOR THE MACHINE REQUESTING THE CERTIFICATE}"
KeySpec = 1
KeyLength = 2048
Exportable = TRUE
MachineKeySet = TRUE
ProviderName = "Microsoft Software Key Storage Provider"
RequestType = PKCS10
HashAlgorithm = SHA256

[Extensions]
2.5.29.17 = "{text}"
_continue_ = "dns={DNS ENTRY FOR THE MACHINE REQUESTING THE CERTIFICATE}&"

[RequestAttributes]
CertificateTemplate = ServerTLS
```
## Generate request:
In PowerShell run:
```PowerShell
certreq -new {NAME}.inf {NAME}.req
```

## Submit request:
In PowerShell run:
```PowerShell
certreq -submit {NAME}.inf {NAME}.req
```
Select your Enterprise CA 

## Issue certificate:
In PowerShell run:
```PowerShell
certreq -accept {NAME}.req
```

## Exporting the certificate:
1. Open **mmc** -> Click **File** -> **Add/Remove snap-in...** -> Double click **Certificates** -> **Computer account** -> **Local computer** -> **Finish** -> **Ok**
2. **Certificates (Local Computer)** -> **Personal** -> **Certificates** -> Right Click **{DNS ENTRY FOR THE MACHINE REQUESTING THE CERTIFICATE}** -> **All taks** -> **Export**
 3. Select **Yes, export the private key** -> **Personal Information Exchange - PKCS # 12 (.PFX)** -> Select **Include all certificates in the certification path if possible** & **Enable certificate privacy** -> Set a password -> Select Encryption **AE256-SHA256** -> File name **{NAME}.pfx** -> **Finish**
 4. Copy the file and transfer it to the appropriate machine.

## Extracting private key command:
```
openssl pkcs12 -in {name}.pfx -nocerts -nodes -out {name}.key
``` 
## Extracting certificate command:
```
openssl pkcs12 -in {name}.pfx -nocerts -nokeys -out {name}.crt
``` 



    




