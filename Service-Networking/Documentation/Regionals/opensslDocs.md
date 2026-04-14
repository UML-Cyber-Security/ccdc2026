## Step 1
First create an intermediate cnf file that will set specific configurations for the intermediary CA:

```
[ req ]
default_bits       = 4096
default_md         = sha256
prompt             = no
encrypt_key        = no
distinguished_name = dn
req_extensions     = v3_req

[ dn ]
C  = US
ST = Massachusetts
L  = Lowell
O  = ChefOPs
CN = ChefOPs pfSense Intermediate CA

[ v3_req ]
basicConstraints = critical, CA:true, pathlen:0
keyUsage = critical, digitalSignature, cRLSign, keyCertSign
subjectKeyIdentifier = hash
```

## Step 2
Generate a private key
`openssl genrsa -out intermediate.key 4096`

## Step 3
Generate the CSR via
`openssl req -new -key intermediate.key -out intermediate.csr -config intermediate.cnf`

## Step 4
Submit this csr to the Windows root

## Step 5
Import this issued cert to the PfSense system via the GUI

## Step 6
You can verify the cert with
`openssl x509 -in intermediate.crt -text -noout`

## PKI Structure
```
Windows Root CA (offline)
        │
        │
pfSense Intermediate CA
        │
        ├── VPN Certificates
        ├── WebGUI Certificates
        ├── Internal TLS certs
        └── Device certificates
```