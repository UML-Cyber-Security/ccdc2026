# Setting Up Sidecar

### Create an Agent

We will need an agent to connect to the Graylog server. If one doesn't already exist, create a CentOS machine to install sidecar on.

#### Installing CentOS

1. Create a new VM
2. Use the following specs for the machine:

![Screenshot of Specs for Machine](<images/Screenshot 2025-11-25 at 1.21.11 PM.png>)

3. Boot Machine
4. Go through installation process of CentOS (This will take a while, took me ~1hr)
5. Create a user "blueteam" with password and ALSO enable administrative priviledges.
6. Reboot
7. Login with credentials

### Installing Sidecar

1. Go to Firefox and download the script file from the UML CCDC github [here](https://github.com/UML-Cyber-Security/ccdc2025-nationals/blob/main/Service-SOC/Graylog/0-Scripts/LIN%20-%20(Sidecar)%20WIP.sh).

2. Open terminal and go to directory where 'LIN - (Sidecar) WIP.sh' is located (If it was moved before opening terminal)

3. Make the script executable: `chmod +x 'LIN - (Sidecar) WIP.sh'`

4. Run the script: `sudo ./'LIN - (Sidecar) WIP.sh'`

5. Select OS type (CentOS - Option 2)

6. Enter Graylog server machine ip (mine was 192.168.1.182 when testing on student-1)

7. Enter API Token from Graylog Machine (used same one as windows Sidecar: `1i2a52pk9pkd47fv2ki4asagqek4sg96ldhqibepk95eq4f788vp`)

8. Make sure that .yml file has server address "http://<MACHINE_IP_ADDRESS>:9000/api" and api key in .yml file and enable/restart through systemctl for `graylog-sidecar`