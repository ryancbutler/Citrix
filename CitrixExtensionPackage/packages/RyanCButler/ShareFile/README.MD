# ShareFile

## migrate-sfusers.ps1

Rough set of PowerShell functions that can be used to report on ShareFile usage and migrate users and folders to new or existing zone.  Should probably be converted to a module at some point.

 [See ShareFile SDK](https://github.com/citrix/ShareFile-PowerShell)

 **Before running**
 1. Grab [PowerShell SDK and install](https://github.com/citrix/ShareFile-PowerShell/releases)
 2. Create ShareFile [authentication file:](https://github.com/citrix/ShareFile-PowerShell/wiki/Getting-Started) `New-SfClient -Name "C:\Users\Username\Documents\MySubdomain.sfps"`
 3. Adjust variables in script and run needed functions
