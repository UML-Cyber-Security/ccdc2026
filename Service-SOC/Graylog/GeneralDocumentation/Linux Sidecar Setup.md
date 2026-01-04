# Proper Linux Sidecar Setup 

WHAT THIS IS:  
Brief guide tested and confirmed on Linux Debian distros, that correctly sets up a Graylog sidecar "agents" Auditbeat service to pull logs from auditd's audit logs. This allows Graylogs Auditbeat to be ran alongside auditd, which would allow for Graylog and local logging. <br>


## 1. Generate a sidecar token from the Graylog dashboard 

Go to -> "System/Inputs" on the top navbar.  
Click -> "Sidecars".  
Click -> "Create or reuse a token for the Graylog-sidecar user".  
Enter a descriptive token name, and a "Token Time to Live". Remember this token, dont lose it!!

## 2. Install the Graylog Sidecar "Agent"  

Log into the machine you want the agent on. Run the script in /Graylog/0-Scripts/(Linux Sidecar Install script). This install script might change in the future - so make sure you are running the correct one. Make sure to also enter the correct Graylog server IP and token.  

For example: If the Graylog server has the following IP: 192.168.1.182, in the script you should enter: `http://192.168.1.182:9000/api`.

## 3. Add a Graylog Server Input  

Back on the Graylog web interface, go to -> "System/Inputs" on the top navbar.  
Click -> "Inputs".  
Select -> "Beats", "Launch new input"
Name: "Sidecar beats input"
Bind address: "0.0.0.0"
Port: "5044"
Everything else: Keep as default.  

Launch the input.

## 4. Configure the Sidecar auditbeat Collector 

Now, the auditbeat sidecar collector needs to be configured to pull logs from the auditd /var/log/audit.log.

On the Graylog server, go to -> "System/Inputs".  
Click -> "Sidecars".  
Click -> "Configuration". 
Select -> "auditbeat-linux-default"

In the GUI configuration file, delete all of the `Modules configuration` and `auditbeat.modules:` (Make sure to keep settings above, and file integrity modules below). Replcase the `auditbeat.modules` part with the following, and click "Update configuration":  

```
# =========================== Modules configuration ============================
auditbeat.modules:

- module: auditd
  log:
    enabled: true
    file: /var/log/audit/audit.log
  # optional: resolve uid/gid to names
  resolve_ids: true
```

### 4.1 Example full config file 

The full configuration file should now look something like this:
```
# Required settings
fields_under_root: true
fields.collector_node_id: ${sidecar.nodeName}
fields.gl2_source_collector: ${sidecar.nodeId}


output.logstash:
   hosts: ["${user.graylog_host}:5044"]
path:
   data: ${sidecar.spoolDir!"/var/lib/graylog-sidecar/collectors/auditbeat"}/data
   logs: ${sidecar.spoolDir!"/var/lib/graylog-sidecar/collectors/auditbeat"}/log
fields:
  event_source_product: linux_auditbeat

# You can find the full configuration reference here:
# https://www.elastic.co/guide/en/beats/auditbeat/index.html

# =========================== Modules configuration ============================
auditbeat.modules:

- module: auditd
  log:
    enabled: true
    file: /var/log/audit/audit.log   # auditd writes this
  # optional: resolve uid/gid to names
  resolve_ids: true

# The file integrity module sends events when files are changed (created, updated, deleted).
# The events contain file metadata and hashes.
- module: file_integrity
  paths:
  - /bin
  - /usr/bin
  - /sbin
  - /usr/sbin
  - /etc
  - /etc/graylog/server
  exclude_files:
  - '(?i)\.sw[nop]$'
  - '~$'
  - '/\.git($|/)'
  include_files: []
  scan_at_start: true
  scan_rate_per_sec: 50 MiB
  max_file_size: 100 MiB
  hash_types: [sha256]
  recursive: false
```