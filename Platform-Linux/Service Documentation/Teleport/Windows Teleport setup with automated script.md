# Windows Teleport setup with automated script

**Authors:** Ofir, Irakli

## Generate AD Configuration Script

On the Teleport machine, run:

```bash
sudo tctl desktop bootstrap > configure-ad.ps1
```

Move the script to the AD machine.

> [!IMPORTANT]
> Only if your certificate authority is set up on a separate machine: download the CA certificate as a .pem file from the CA machine and transfer it to the AD machine.

Edit configure-ad.ps1 to use the following line as the certificate path:

```powershell
$WindowsPEMfile = 'C:\path\to\your\certificate.pem'
```

Run the script to generate all LDAP data required for Windows Desktop Services.

## Configure Teleport on Linux

Edit /etc/teleport.yaml to include the following:
```yaml
windows_desktop_service:
  enabled: true
  listen_addr: 0.0.0.0:3389
  ldap:
    addr: "<LDAP_SERVER_IP>:636"           # Replace with your LDAP server IP
    insecure_skip_verify: true
    domain: "<YOUR_DOMAIN>"                # Replace with your AD domain, e.g., example.com
    username: "<DOMAIN\\USER>"             # Replace with a service account
    sid: "<USER_SID>"                       # Replace with the SID of the service account
    der_ca_file: "<PATH_TO_CA_CERT>"       # Replace with path to CA certificate, e.g., /etc/teleport/ca/ldap-ca-cert.cer
  discovery_configs:
    - base_dn: "*"                          # Use "*" to search all objects

```

> [!IMPORTANT]
> listen_addr: 0.0.0.0:3389 is required.\
> insecure_skip_verify: true skips TLS validation.\
> If full TLS validation is attempted in the future, der_ca_file would need to point to a cert issued to the AD by the CA. Additionally, the Linux machine would need to trust all CA-signed certificates. (This is theoretical and has not been tested.)

Enable and start Teleport:

```bash
sudo systemctl enable teleport
sudo systemctl start teleport
```

## Create Windows Desktop Admin Role

Create Windows-Desktop-Admins.yaml with the following content:

```yaml
kind: role
version: v5
metadata:
  name: windows-desktop-admins
spec:
  allow:
    windows_desktop_labels:
      "*": "*"
    windows_desktop_logins: ["Administrator"]
```

Run the following command to create the role in Teleport:

```bash
tctl create -f windows-desktop-admins.yaml
```

##Assign Role to Teleport User

Next, assign the newly created role to the Teleport user by running:

```bash
tsh login --proxy=<TELEPORT_PROXY> --user=<USERNAME> --insecure
ROLES=$(tsh status -f json | jq -r '.active.roles | join(",")')
tctl users update $(tsh status -f json | jq -r '.active.username') \
  --set-roles "${ROLES?},windows-desktop-admins"
sudo systemctl restart teleport
```

> [!IMPORTANT]
> Replace <TELEPORT_PROXY> with your Teleport proxy address, e.g., 10.0.3.37.\
> Replace <USERNAME> with the correct Teleport user.

## Verification

The Windows machines should now appear in the Teleport UI.

> [!IMPORTANT]
> Machines must have consistent names in Active Directory, DNS, and the actual machine name, and must have a DNS entry.
