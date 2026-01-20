## WIP Integrating Alert Manager with Falco Rules 

Add to loki.yaml

```yaml
ruler:
  alertmanager_url: http://alertmanager:9093
  enable_api: true

  storage:
    type: local
    local:
      directory: /etc/loki/rules

  rule_path: /tmp/loki-rules
```

alertmanager.yml
```yaml
global:
  resolve_timeout: 5m

route:
  receiver: default
  group_by: ['alertname', 'severity', 'rule']
  group_wait: 10s
  group_interval: 2m
  repeat_interval: 30m

receivers:
  - name: default
    webhook_configs:
      - url: http://127.0.0.1:9999/does-not-exist
        send_resolved: true

        ##### run alertmanager container
        ##### docker run -d \ --name alertmanager \ --restart unless-stopped \ -p 9093:9093 \ --volume /etc/alertmanager/alertmanager.yml:/etc/alertmanager/alertmanager.yml:ro \ prom/alertmanager \ --config.file=/etc/alertmanager/alertmanager.yml
        ##### docker run -d \ --name loki \ --restart unless-stopped \ -p 3100:3100 \ -v /etc/loki/loki.yaml:/etc/loki/loki.yaml:ro \ -v /etc/loki/rules:/etc/loki/rules:ro \ grafana/loki:latest \ --config.file=/etc/loki/loki.yaml
```

falco-alerts.yml
```yaml
groups:
  - name: falco-alerts
    rules:
      - alert: FalcoHighSeverity
        expr: |
          sum(
            count_over_time(
              {container=~"falco-.*"}
              | json
              | priority=~"(?i)(Emergency|Alert|Critical|Error)"
              [2m]
            )
          ) > 0
        for: 30s
        labels:
          severity: high
          source: falco
        annotations:
          summary: "Falco high severity event detected"
          description: "High severity Falco events detected in the last 2 minutes."

      - alert: FalcoCriticalTextFallback
        expr: |
          sum(
            count_over_time(
              {container=~"falco-.*"} |= "Critical"
              [2m]
            )
          ) > 0
        for: 30s
        labels:
          severity: high
          source: falco
        annotations:
          summary: "Falco critical event (text fallback)"
          description: "Falco log line matching 'Critical' detected in last 2 minutes."
```