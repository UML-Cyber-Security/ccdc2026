# How to create Account & Password group policies 
Authors: Ofir and Irakli\
How to create Account & Password group policies 

## getting to **Account Policies**

1. open **Group Oolicy Management** 
2. click on the arrow besides **forest: <your forest name>** -> **Domains** -> **<your forest name>.com**
3. right click **Default Domain Policy** -> **edit**
4. click on the arrow besides **Computer COnfiguration** -> **Windows Settings** -> **Secuirity Settings** -> **Account Policies**

to follow CIS Benchmark and NIST 800-63B recommendations

## Password Policy

**Enforce password history** = 24 passwords remembered\
**Minimum password age** = 0\
**Minimum password length** = 14 characters


## account Lockout Policy

**Account lockout duration** = 15 minutes\
**Account lockout threshold** = 10 invalid logon attempts\
**Allow Administrator account lockout** = Enabled\
**Reset account lockout counter after** 15 minutes

