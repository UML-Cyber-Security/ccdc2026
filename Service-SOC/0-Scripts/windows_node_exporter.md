#### windows ca:
1. on the windows vm:
```
cd ~/Downdloads 

#install
	Invoke-WebRequest -Uri "https://github.com/prometheus-community/windows_exporter/releases/download/v0.25.1/windows_exporter-0.25.1-amd64.msi" -OutFile "windows_exporter.msi"



#add firewall rule
	New-NetFirewallRule -DisplayName "Windows Exporter" -Direction Inbound -LocalPort 9182 -Protocol TCP -Action Allow
	
#open up http://localhost:9182 check to make sure metrics show up
```

2. On the soc server:
add to prometheus.yml
```
- job_name: 'windows-workstation'
    static_configs:
      - targets: ['192.168.1.52:9182']
```

3. restart prometheus