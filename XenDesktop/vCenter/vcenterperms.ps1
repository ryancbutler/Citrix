<#
.SYNOPSIS
   Verifies and sets vCenter role permissions for XenDesktop 7.x (https://support.citrix.com/article/CTX214389)
.DESCRIPTION
   Verifies and sets vCenter role permissions for XenDesktop 7.x (https://support.citrix.com/article/CTX214389)   
   Version: 1.6
   By: Ryan Butler 05-03-17
   Updated: Ryan Butler 07-20-18
   Updated: Ryan Butler 07-23-18: Disable propagation for account
.NOTES 
   Twitter: ryan_c_butler
   Website: Techdrabble.com
   Requires: Powershell v5 or greater and PowerCli (https://blogs.vmware.com/PowerCLI/2017/04/powercli-install-process-powershell-gallery.html) snapins
.LINK
   https://github.com/ryancbutler/Citrix
.PARAMETER VCENTER
   vCenter to connect to
.PARAMETER SET
   Creates and sets role permissions if not found
.PARAMETER ROLE
   Name of vCenter role to use
.PARAMETER Creds
    Credential object to authenticate to vcenter with
.PARAMETER User
    Vcenter service account (domain\myuser)
.EXAMPLE
   .\vcenterperms.ps1 -vcenter vcenter.lab.com -role MYROLE
   Checks for role "MYROLE" for proper permissions. Does not set anything
.EXAMPLE
   .\vcenterperms.ps1 -vcenter vcenter.lab.com -role MYROLE -set
   Checks for role "MYROLE" for proper permissions.  If not found creates and sets all missing permissions on role.
.EXAMPLE
   .\vcenterperms.ps1 -vcenter vcenter.lab.com -role MYROLE -user "domain\user"
   User selects DataCenter, checks for role "MYROLE" for proper permissions and checks for domain\user assignment to role on datacenter.  Does not set anything.
.EXAMPLE
   .\vcenterperms.ps1 -vcenter vcenter.lab.com -role MYROLE -user "domain\user" -set
   User selects DataCenter, checks for role "MYROLE" for proper permissions and checks for domain\user assignment to role on datacenter.  If not found creates and sets all missing permissions and assigns user.
.EXAMPLE
   $creds = get-credential
   .\vcenterperms.ps1 -vcenter vcenter.lab.com -role MYROLE -creds $creds
   Checks for role "MYROLE" for proper permissions. Does not set anything.  Uses $creds for authentication
#>
[CmdletBinding()]
param
(
	[Parameter(Position = 0,Mandatory = $true)]
	[string]$vcenter,
	[Parameter(Position = 1,Mandatory = $true)]
	[string]$role,
	[Parameter(Position = 2,Mandatory = $false)]
	[System.Management.Automation.PSCredential]$Creds = (Get-Credential),
	[Parameter(Position = 3,Mandatory = $false)]
	[string]$user,
	[Parameter(Position = 4,Mandatory = $false)]
	[switch]$checkdatacenter,
	[switch]$set
)

Import-Module VMware.PowerCLI -ErrorAction Stop

$privs = @("Datastore.AllocateSpace",
	"Datastore.Browse",
	"Datastore.FileManagement",
	"Global.ManageCustomFields",
	"Global.SetCustomField",
	"Network.Assign",
	"Resource.AssignVMToPool",
	"System.Anonymous",
	"System.Read",
	"System.View",
	"VirtualMachine.Config.AddExistingDisk",
	"VirtualMachine.Config.AddNewDisk",
	"VirtualMachine.Config.AddRemoveDevice",
	"VirtualMachine.Config.AdvancedConfig",
	"VirtualMachine.Config.CPUCount",
	"VirtualMachine.Config.EditDevice",
	"VirtualMachine.Config.Memory",
	"VirtualMachine.Config.RemoveDisk",
	"VirtualMachine.Config.Settings",
	"VirtualMachine.Interact.PowerOff",
	"VirtualMachine.Interact.PowerOn",
	"VirtualMachine.Interact.Reset",
	"VirtualMachine.Interact.Suspend",
	"VirtualMachine.Inventory.Create",
	"VirtualMachine.Inventory.CreateFromExisting",
	"VirtualMachine.Inventory.Delete",
	"VirtualMachine.Provisioning.Clone",
	"VirtualMachine.Provisioning.CloneTemplate",
	"VirtualMachine.Provisioning.DeployTemplate",
	"VirtualMachine.State.CreateSnapshot")


#Connects to vCenter
Connect-VIServer -Server $vcenter -Credential ($creds) -ErrorAction Stop

#Tests to see if the role exists
function Test-role ($role)
{
	try
	{
		$svcrole = Get-VIRole -Name $role -ErrorAction stop
	}
	catch
	{
		$svcrole = $false
	}
	return $svcrole
}

#Sets ROLE permissions
function set-perms
{
	$results = @()
	foreach ($priv in $privs)
	{
		$temp = New-Object PSCustomObject
		$addpriv = Get-VIPrivilege -Id $priv
		if ($svcsperms -notcontains $priv)
		{
			$found = $false
			if ($set)
			{
				Write-Host "Missing $($addpriv.id)" -ForegroundColor Yellow
				Set-VIRole -AddPrivilege $addpriv -Role $role
			}
		}
		else
		{
			Write-Host "$($addpriv.id) present" -ForegroundColor Green
			$found = $true
		}

		$temp | Add-Member -NotePropertyName "Name" -NotePropertyValue $addpriv.Name
		$temp | Add-Member -NotePropertyName "ID" -NotePropertyValue $priv
		$temp | Add-Member -NotePropertyName "Found" -NotePropertyValue $found

		$results += $temp
	}
	return $results
}

#Tests for principal and role assigned to datacenter
function Test-Datacenter
{
	try {
		$perms = Get-VIPermission -Entity $datacenter -Principal $user -ErrorAction Stop | Where-Object { $_.role -eq $role }
	}
	catch
	{
		Write-Host "$user not found. Check username and run again." -ForegroundColor yellow
		$found = $false
		return $found
	}

	if ($perms -eq $null)
	{
		Write-Host "$user found but not assigned to specific $role" -ForegroundColor Yellow
		$found = $false
	}
	else {
		Write-Host "$user found and assigned to $role on $($datacenter.name)" -ForegroundColor Green
		$found = $true
	}

	return $found
}

#Assigns principal and role to datacenter
function Set-DatacenterPerm
{
	Write-Host "Assigning $user to $role on $($datacenter.name)" -ForegroundColor yellow
	New-VIPermission -Entity $datacenter -Principal $user -Role $role -ErrorAction Stop -Propagate $false | Out-Null
}

$svcrole = Test-role $role
$svcsperms = $svcrole.PrivilegeList

if ($svcrole)
{
	Write-Host "$($role) role found" -ForegroundColor Green
	$results = set-perms
	if (-not [string]::IsNullOrWhiteSpace($user))
	{
		$datacenter = Get-Datacenter | Out-GridView -Passthru
		$dctest = Test-Datacenter
		if ($dctest -eq $false -and $set -eq $true)
		{
			Set-DatacenterPerm
		}
	}
}
elseif ($svcrole -eq $false -and $set)
{
	Write-Host "$($role) role not found and creating" -ForegroundColor Yellow
	#Creates ROLE
	New-VIRole -Name $role | Out-Null
	$results = set-perms
	if (-not [string]::IsNullOrWhiteSpace($user))
	{
		$datacenter = Get-Datacenter | Out-GridView -Passthru
		$dctest = Test-Datacenter
		if ($dctest -eq $false -and $set -eq $true)
		{
			Set-DatacenterPerm
		}
	}
}
else
{
	Write-Host "$($role) role not found and NOT creating. Use -set switch." -ForegroundColor Yellow
}

#disconnect vCenter
Disconnect-VIServer -Confirm:$false | Out-Null

#Returns table if permissions aren't set correctly
if ($set -eq $false -and $svcrole -ne $false)
{
	$results | Out-GridView
}
