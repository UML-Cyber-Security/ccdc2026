# How To Deploy a Grafana + Prometheus + Loki Monitoring Stack

**Author:** Michael Leahy  
**Last Updated:** February 18, 2026

## Overview
This document details how to deploy a monitoring and log aggregation stack using Prometheus, Loki, Grafana, Promtail, and Node Exporter for SOC visibility.

## Prerequisites
1. Make sure the following ports are open on the SOC machine:
    - 3000 (Grafana)
    - 9090 (Prometheus)
    - 3100 (Loki)
2. Open port 9100 on the client machines
3. Ensure all scripts are executable with
    ```bash
    sudo chmod +x *.sh
    ```
4. Ensure client machines can reach the SOC server over the network

## SOC Server Setup
1. On the machine to be used as the SOC machine, run:
    ```bash
    sudo ./prometheusGrafana.sh
    sudo ./loki.sh
    sudo ./promtail.sh
    ```
    These scripts can be found in the Grafana > 0-Scripts folder.

2. Open the prometheus.yaml file and add these lines for each machine that will be sending logs:
    ```yaml
    - job_name: "<machine_name>"
      static_configs:
        - targets:["<client_machine_ip>:9100"]
    ```
    Save the config file and then restart the prometheus service using
    ```bash
    sudo systemctl restart prometheus.service
    ```

3. Verify that the SOC machine was setup properly by checking the status of the services:
    ```bash
    sudo systemctl status prometheus
    sudo systemctl status loki
    sudo systemctl status grafana-server
    ```

## Linux Client Machine Setup
1. On every machine that sends logs, run:
    ```bash
    sudo ./setup-linux-client <host_name> <soc_server_ip>
    sudo ./auditd-install.sh
    ```
    The `setup-linux-client.sh` script can be found in the Grafana > 0-Scripts folder. The `auditd-install.sh` script can be found in the Initial folder

2. Verify that the client machine was setup properly by checking the status of the services:
    ```bash
    sudo systemctl status promtail
    sudo systemctl status auditd
    ```

## Accessing Web Interfaces
### I) Prometheus
The webpage for Prometheus is located at `http://<soc_machine_ip>:9090`.
1. Navigate to *Status* > *Target health*. Here you can see if machines have been properly connected to the SOC machine.

### II) Grafana
The webpage for Grafana is located at `http://<soc_machine_ip>:3000`. The default login credentials are:  
```text
Username: admin
Password: admin
```
Change this after logging in.

1. Go to *Data Sources* > *Add Data Source*. Add a data source for Prometheus and Loki.
2. Verify logs are being received. Go to *Explore*, select Loki as the source, and run this query:
    ```json
    {job="auditd"}
    ```
    If everything was setup correctly, you should see logs.
3. Go to *Dashboards* > *Import Dashboard*. Import dashboard ID 1860 (Node Exporter Full) to visualize system metrics collected by Prometheus.
