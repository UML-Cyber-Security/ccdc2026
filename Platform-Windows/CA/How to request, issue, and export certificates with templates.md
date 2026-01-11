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

## Generating, submitting, and issuing certificate request:
Run the following commands in PowerShell as Administrator

### Generate request:
```PowerShell
certreq -new {NAME}.inf {NAME}.req
```

### Submit request:
```PowerShell
certreq -submit {NAME}.inf {NAME}.req
```
Select your Enterprise CA 

### Issue certificate:
```PowerShell
certreq -accept {NAME}.req
```

## Exporting the certificate (GUI):
1. Open **mmc** -> Click **File** -> **Add/Remove snap-in...** -> Double click **Certificates** -> **Computer account** -> **Local computer** -> **Finish** -> **Ok**
2. **Certificates (Local Computer)** -> **Personal** -> **Certificates** -> Right Click **{DNS ENTRY FOR THE MACHINE REQUESTING THE CERTIFICATE}** -> **All taks** -> **Export**
3. Select **Yes, export the private key** -> **Personal Information Exchange - PKCS # 12 (.PFX)** -> Select **Include all certificates in the certification path if possible** & **Enable certificate privacy** -> Set a password -> Select Encryption **AE256-SHA256** -> File name **{NAME}.pfx** -> **Finish**
4. Copy the file and transfer it to the appropriate machine.

## Exporting the certificate (PowerShell Administrator):
```PowerShell
$cert = Get-ChildItem Cert:\LocalMachine\My |
    Where-Object { $_.Subject -like "*CN={DNS ENTRY FOR THE MACHINE REQUESTING THE CERTIFICATE}*" }

$pwd = ConvertTo-SecureString "PFX_PASSWORD_HERE" -AsPlainText -Force

Export-PfxCertificate `
    -Cert $cert `
    -FilePath "C:\Path\To\{NAME}.pfx" `
    -Password $pwd `
    -ChainOption BuildChain `
    -CryptoAlgorithmOption AES256_SHA256
```

## Extracting private key command:
```
openssl pkcs12 -in {name}.pfx -nocerts -nodes -out {name}.key
``` 
## Extracting certificate command:
```
openssl pkcs12 -in {name}.pfx -nocerts -nokeys -out {name}.crt
``` 