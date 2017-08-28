# Netscaler
Netscaler Scripts and files

If you receive an error within PowerShell from Windows 7 or Windows 2008 R2 SP1 like the one mentioned below.  Please install [Windows Management Framework 4.0 KB2819745](https://www.microsoft.com/en-us/download/details.aspx?id=40855)
![Alt text](https://github.com/ryancbutler/Citrix/blob/images/images/ns-resterror.png?raw=true)

## set-nsssl.ps1
**CREATED: 3-17-16**

Please see [My blog](http://techdrabble.com/citrix/16-getting-an-a-for-netscaler-from-ssllabs-com) for more information.

Based on this [Citrix blog](https://www.citrix.com/blogs/2015/05/22/scoring-an-a-at-ssllabs-com-with-citrix-netscaler-the-sequel)
- Checks and sets all SSL Netscaler managment, load balancer, Netscaler Gateway and content switch VIPS
- Enables TLS 1.2
- Disables SSLv2 and SSLv3
- Removes "Default" ciphers
- Creates new cipher group and binds to VIPs while removing all other ciphers (auto detects VPX with corresponding supported ciphers)
- Creates and binds Diffie-Hellman (DH) 2048 bit key (Forward Secrecy)
- Creates and binds "Strict Transport Security policy"
- Allow secure renegotiation
- Results in A+ on https://www.ssllabs.com/ssltest

**NOTE: Must be firmware 10.5 or greater**

**USE WITH CAUTION**
### Changelog
- 3-17-16:
    - Added port 3008 and 3009 to managment ips
- 3-28-16:
    - Rewrite to reflect PowerShell best practice
    - Can adjust SSL Managment IPs
- 6-13-16 (Tested with VPX 11.0 65.31)
    - Adjusted ciphers to reflect recent 6-9-16 [Citrix blog](https://www.citrix.com/blogs/2016/06/09/scoring-an-a-at-ssllabs-com-with-citrix-netscaler-2016-update)
    - Ciphers are now the same for VPX or MPX\SDX
    - Removes management IPs (NSIP) from being adjusted by default.
    - Enables TLS 1.2
- 6-14-16
    - Added HTTPS connection option
    - Added SSL renegotiation
- 12-29-16
	- Added NS firmware version check (10.5 or greater required due to 'systemfile' API)
- 03-13-16
  - Added check for [Default SSL Profiles](https://docs.citrix.com/en-us/netscaler/11-1/ssl/ssl-profiles1/ssl-enabling-the-default-profile.html) and if enabled uses SSL profile for all VIPS
  - Created parameter to enable default SSL profile option on 11.1 or greater
- 06-02-17
  - Added Error handling
  - Changed how default profiles bind cipher groups
  - Added a policy priority argument
- 08-28-17
  - Formatted and added to PS gallery

### PS Gallery
If running PowerShell version 5 or above you can install via [Microsoft PowerShell Gallery](https://www.powershellgallery.com/)

#### Install
```
Install-Script -Name set-nsssl -Scope currentuser
```

### Inspect
```
Save-Script -Name set-nsssl -Path <path>
```

#### Update
```
Update-Script set-nsssl
```

## upgrade-ns.ps1
**CREATED: 6-30-16**

Uses the 11.1 REST API to upgrade Netscaler firmware. See [Blog Post](http://techdrabble.com/citrix/20-upgrade-netscaler-via-rest-api-install-command) for more information

**NOTE: Must be firmware 11.1 or greater**

### Changelog
- 12-29-16: Added NS version check

## get-nslicexp.ps1
**CREATED: 8-14-16**

Grabs Netscaler license expiration information via REST.  See [Blog Post](http://www.techdrabble.com/citrix/netscaler/23-check-netscaler-license-expiration-information-quickly-via-powershell) for more information and detailed usage.

**NOTE: Must be firmware 10.5 or greater**

### Changelog
- 8-14-16: Now compares Netscaler time VS system time of script host
- 12-14-16: Fix for double digit days
- 12-28-16: Better error handling when grabbing license files and NS version check
- 08-28-17: Formatted and added to PS gallery

### PS Gallery
If running PowerShell version 5 or above you can install via [Microsoft PowerShell Gallery](https://www.powershellgallery.com/)

#### Install
```
Install-Script -Name get-nslicexp -Scope currentuser
```
### Inspect
```
Save-Script -Name get-nslicexp -Path <path>
```
#### Update
```
Update-Script get-nslicexp
```