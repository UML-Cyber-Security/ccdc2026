$ProgressPreference = 'SilentlyContinue'; 
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; 
iex ((New-Object System.Net.WebClient).DownloadString('https://raw.githubusercontent.com/DigitalRuby/IPBan/master/IPBanCore/Windows/Scripts/install_latest.ps1'))