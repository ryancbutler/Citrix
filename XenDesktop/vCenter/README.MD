# vcenterperms.ps1
Verifies and sets vCenter role [permissions for XenDesktop 7.x](https://support.citrix.com/article/CTX214389)

## Usage
Checks for role "MYROLE" for proper permissions. Does not set anything
```
.\vcenterperms.ps1 -vcenter vcenter.lab.com -role MYROLE
```

Checks for role "MYROLE" for proper permissions.  If not found creates and sets all missing permissions on role.
```
.\vcenterperms.ps1 -vcenter vcenter.lab.com -role MYROLE -set
```

User selects DataCenter, checks for role "MYROLE" for proper permissions and checks for domain\user assignment to role on datacenter.  Does not set anything.
```
.\vcenterperms.ps1 -vcenter vcenter.lab.com -role MYROLE -user "domain\user"
```

User selects DataCenter object, checks for role "MYROLE" for proper permissions and checks for domain\user assignment to role on datacenter.  If not found creates and sets all missing permissions and assigns user to selected datacenter.
```
.\vcenterperms.ps1 -vcenter vcenter.lab.com -role MYROLE -user "domain\user" -set
```

Checks for role "MYROLE" for proper permissions. Does not set anything.  Uses $creds for authentication
```
$creds = get-credential
.\vcenterperms.ps1 -vcenter vcenter.lab.com -role MYROLE -creds $creds
```


