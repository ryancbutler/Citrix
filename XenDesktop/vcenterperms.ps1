<#
.SYNOPSIS
   Verifies and sets vCenter role permissions for XenDesktop 7.x (https://support.citrix.com/article/CTX214389)
.DESCRIPTION
   Verifies and sets vCenter role permissions for XenDesktop 7.x (https://support.citrix.com/article/CTX214389)   
   Version: 1.0
   By: Ryan Butler 05-03-17
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
.EXAMPLE
   .\vcenterperms.ps1 -vcenter vcenter.lab.com -role MYROLE
   Checks for role "MYROLE" for proper permissions. Does not set anything
.EXAMPLE
   .\vcenterperms.ps1 -vcenter vcenter.lab.com -role MYROLE -set
   Checks for role "MYROLE" for proper permissions.  If not found creates and sets all missing permissions.
#>
Param
(
    [Parameter(Position=0,Mandatory=$true)]
    [string]$vcenter,
    [Parameter(Position=1,Mandatory=$true)]
    [String]$role,
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


connect-viserver -Server $vcenter -Credential (get-credential)
CLS

function check-role ($role)
{
    Try
    {
        $svcrole = get-virole -Name $role -ErrorAction stop
    }
    Catch
    {
        $svcrole = $false        
    }
    return $svcrole
}

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
                if($set)
                {
                write-host "Missing $($addpriv.id)" -ForegroundColor Yellow    
                Set-VIRole -AddPrivilege $addpriv -Role $role
                }
            }
            else
            {
            write-host "$($addpriv.id) present" -ForegroundColor Green
            $found = $true
            }
        
        $temp|Add-Member -NotePropertyName "Name" -NotePropertyValue $addpriv.Name
        $temp|Add-Member -NotePropertyName "ID" -NotePropertyValue $priv
        $temp|Add-Member -NotePropertyName "Found" -NotePropertyValue $found

        $results += $temp
    }
    return $results
}

$svcrole = check-role $role
$svcsperms = $svcrole.PrivilegeList

if ($svcrole)
{
    write-host "Role found" -ForegroundColor Green
    $results = set-perms
}
elseif($svcrole -eq $false -and $set)
{
    write-host "Role not found and creating" -ForegroundColor Yellow
    New-VIRole -Name $role|Out-Null
    $results = set-perms   
}
else
{
    write-host "$($role) not found and NOT creating. Use -set switch." -ForegroundColor Yellow
}

Disconnect-VIServer -Confirm:$false|Out-Null
if($set -eq $false -and $svcrole -ne $false)
{
    $results|ft -AutoSize
}
