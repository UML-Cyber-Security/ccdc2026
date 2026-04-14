# Windows Local User Teleport Setup

WHAT THIS IS:  
Brief guide that explains how to properly configure Teleport x Local Windows integration. This has been tested and verified on Teleport 18.7 Community edition, Ubuntu. This guide follows the official docs - with some important changes to prevent errors and lengthy debugging.

PRE-REQ:
- Teleport verion at least 18.xxx
- Time needs to be synced between the Teleport and Windows machines


## 1. Prepare the Windows Machine (Windows)
This part can be followed by the official docs (part 1). On the **Windows** machine:

Export the Teleport CA:
```cmd
curl.exe -fo teleport.cer https://teleport.example.com/webapi/auth/export?type=windows
```

Download the Windows Teleport Auth Setup program:
```cmd
curl.exe -fo teleport-windows-auth-setup-v18.7.2-amd64.exe https://cdn.teleport.dev/teleport-windows-auth-setup-v18.7.2-amd64.exe
```
Runt the program and select the Teleport CA you curl'ed previously.

Restart the Windows computer!


## 2. Configure Windows Desktop Service (Linux)

1. Generate a Windows join token, making sure to save this.
```bash
tctl tokens add --type=windowsdesktop
```

2. Paste the token into `/tmp/token1`

3. Edit the `/etc/teleport.yaml` config file to look roughly like the following:
```yaml
auth_service:
  enabled: "yes"
  tokens:
  - "windowsdesktop:d69deeacc71d724a2f778797d0fad8f0"
windows_desktop_service:
  enabled: true
  listen_addr: 0.0.0.0:3028
  static_hosts:
  - name: pos-1
    ad: false
    addr: 192.168.4.214
  - name: ad
    ad: false
    addr: 192.168.4.213
```

4. Restart Teleport
```bash
sudo systemctl enable teleport
sudo systemctl start teleport
```

## 3. Configure Proper Role Access (Linux)

1. On the Teleport machine, add in the users that you would like to have sign into the Window machines.
```bash
nano windows-desktop-admins.yaml
```
```yaml
kind: role
version: v6
metadata:
  name: windows-desktop-admins
spec:
  allow:
    windows_desktop_labels:
      "*": "*"
    windows_desktop_logins: ["Administrator", "alice"]
```

2. Apply this new role with:
```bash
tctl create -f windows-desktop-admins.yaml
```

3. Sign into the Teleport GUI and assign this role to whoever needs to access the Windows stations.