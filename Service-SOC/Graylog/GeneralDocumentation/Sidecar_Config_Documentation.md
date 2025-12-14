# Sidecar Configuration File
WHAT THIS IS:  
This is a description of values in the Graylog Sidecar configuration file that you should set when installing and configuring the Graylog Sidecar. Not all of these are required, but they are recommened to be set in order to have a Graylog Sidecar that functions well.

## 1. server_url
This is the URL of the Graylog server API. The format entered should be:
```
http://<graylog-server_ip>:9000/api/
```  
Example:
```
server_url: "http://192.168.0.98:9000/api/"
```
## 2. server_api_token
This is the API token used to authenticate against the Graylog server API. Create a token by going to the Graylog web interface, navigating to "System" -> "Sidecars" -> "Create or reuse a token for the graylog-sidecar user", and follow the instructions to create a new token.  
  
Example:
```
server_api_token: "<generated-token>"
```
## 3. node_id
This is a unique identifier for each sidecar. A file is created when the sidecar is installed that can be used as the to fill the node_id field. The file path is:
```
file:/etc/graylog/sidecar/node-id
```  
Example:
```
node_id: "file:/etc/graylog/sidecar/node-id"
```
## 4. node_name
This is the name that will help to easily identify the sidecar when looking at logs on the Graylog web interface. Set this to something that will help you know what system this sidecar is installed on.  
  
Example:
```
node_name: "k8s-worker1"
```
## 5. update_interval
This is the update interval in seconds for the sidecar to contact the Graylog server for updates. The default is 10 seconds.
## 6. send_status
This setting enables or disables the sending of status messages from the sidecar to the Graylog server. Set to true to enable status messages, or false to disable them. The default is true.
## 7. list_log_files
This is a list of directories that the sidecar will scan for log files it can send. This value needs to be set for the sidecar to send logs. The default is
```
list_log_files:
  - "/var/log"
```