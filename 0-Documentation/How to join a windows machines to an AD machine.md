
Author: Ofir and Irakli
How to join a windows machines to an AD machine

If your windows machine does not have a unique SID start of by running sysprep and selecting generalize. 
cd C:\Windows\System32\Sysprep
sysprep.exe

After the computer rebooted open:
Control Panel → Network and Internet → Network and Sharing Center → Change adapter settings -> Right-click Ethernet → Properties -> Select Internet Protocol Version 4 (TCP/IPv4) → click Properties

set IP to match spreadsheet
Changed Subnet mask to: 255.255.255.0
Changed the Default gateway to: 10.0.1.1
And changed Preferred DNS to match the IP of the AD machine: 10.0.1.10

open “View advanced system settings”
Click on Computer Name -> change
then add the machine as a member of the base url in this case "ad.zodu.com"
