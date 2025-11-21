# Setting up split barin DNS with multiple domains
Authors: Ofir, Irakli, Seamus\
Setting up split barin DNS with multiple domains

## new domain setup

The following command creates a new domain, which will be used to create internal DNS entries that only machines from specific IP ranges can access.
```powershell
Add-DnsServerPrimaryZone -Name "dev.zodu.com" -ReplicationScope "Domain" -DynamicUpdate "Secure"
```

Run the following command to verify that the previous command was successful.
```powershell
Get-DnsServerZone -Name "dev.zodu.com"
```

## setting up InternalScope and client subnet

Run the following command to create a zone inside dev.zodu.com, which will let us configure who can access dev.zodu.com.
```powershell
Add-DnsServerZoneScope -ZoneName "dev.zodu.com" -Name "InternalScope"
```

To limit access to dev.zodu.com, you need to set up a subnet. Run the following command, changing the name and IP to your desired ones.
```powershell
Add-DnsServerClientSubnet -Name "<NAME>" -IPv4Subnet "10.0.x.0/24"
```

Also, set up a subnet for external IPs.
```powershell
Add-DnsServerClientSubnet -Name "ExternalNetwork" -IPv4Subnet "0.0.0.0/0"
```

To create the policy to block external IPS from accessing dev.zodu.com, run the following command.
```powershell
Add-DnsServerQueryResolutionPolicy -Name "DenyExternalDevZone" ` -Action DENY ` -ClientSubnet "eq,ExternalNetwork" ` -ZoneName "dev.zodu.com"
```

To create the policy to allow internal IPs to access dev.zodu.com, run the following command for each of the subnets you created. You can choose any name, but make sure to match the ClientSubnet name exactly.
```powershell
Add-DnsServerQueryResolutionPolicy -Name "<NAME>" -Action ALLOW -ZoneScope "InternalScope" -ClientSubnet "eq,<SUBNET NAME>" -ZoneName "dev.zodu.com"
```

## Setting up DNS entries

Run the following command, changing the IP and NAME for each of your private machines, to create DNS entries for them
```powershell
Add-DnsServerResourceRecordA -Name "@" -ZoneName "dev.zodu.com" -ZoneScope "InternalScope" -IPv4Address "10.0.1.10"
```


