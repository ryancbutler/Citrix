<#
.SYNOPSIS
   A PowerShell script for upgrading Netscaler firmware via REST API (Versions greater than 11.1)
.DESCRIPTION
   A PowerShell script for upgrading Netscaler firmware via REST API (Firmware greater than 11.1)
.PARAMETER nsip
   DNS Name or IP of the Netscaler that needs to be configured. (MANDATORY)
.PARAMETER adminaccount
   Netscaler admin account (Default: nsroot)
.PARAMETER adminpassword
   Password for the Netscaler admin account (Default: nsroot)
.PARAMETER https
   Use HTTPS for communication to NSSIP
.PARAMETER url
   URL for Netscaler firmware (MANDATORY)
.PARAMETER reboot
    Reboot after upgrade (Default: true)
.PARAMETER callhome
    Enable CallHome (Default: false)
.EXAMPLE
   ./upgrade-ns.ps1 -nsip 10.1.1.2 -url "https://mywebserver/build-11.1-47.14_nc.tgz"
.EXAMPLE
   ./upgrade-ns.ps1 -nsip 10.1.1.2 -url "https://mywebserver/build-11.1-47.14_nc.tgz" -adminaccount nsadmin -adminpassword "mysupersecretpassword" -callhome -noreboot
#>
Param
(
    [Parameter(Mandatory=$true)]$nsip,
    [String]$adminaccount="nsroot",
    [String]$adminpassword="nsroot",
    [switch]$https,
    [Parameter(Mandatory=$true)]$url,
    [switch]$noreboot,
    [switch]$callhome
)


#Tested with Windows 10 and Netscaler 11.1_47.14
#USE AT OWN RISK
#By: Ryan Butler 6-30-16


#Netscaler NSIP login information
if ($https)
{
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls
    [System.Net.ServicePointManager]::ServerCertificateValidationCallback = {$true}
    write-host "Connecting HTTPS" -ForegroundColor Yellow
    $hostname = "https://" + $nsip
}
else
{
    write-host "Connecting HTTP" -ForegroundColor Yellow
    $hostname = "http://" + $nsip
}


$username = $adminaccount
$password = $adminpassword



##Functions
###############################
#Probably not much you have to edit below this
###############################


function Login {

    # Login to NetScaler and save session to global variable
    $body = ConvertTo-JSON @{
        "login"=@{
            "username"="$username";
            "password"="$password"
            }
        }
    try {
    Invoke-RestMethod -uri "$hostname/nitro/v1/config/login" -body $body -SessionVariable NSSession `
    -Headers @{"Content-Type"="application/vnd.com.citrix.netscaler.login+json"} -Method POST |Out-Null
    $Script:NSSession = $local:NSSession
    }
    Catch
    {
    throw $_
    }
}


#Upgrade the NS function
function upgradens ($url, $callhome) {

    # Support function called by CipherGroup
    $body = ConvertTo-JSON @{
        "install"=@{
            "url" = $url;
            "y" = $false;
            "l" = $ch;
            }
        }

    Invoke-RestMethod -uri "$hostname/nitro/v1/config/install" -body $body -WebSession $NSSession `
    -Headers @{"Content-Type"="application/json"} -Method POST -TimeoutSec 600 |Out-Null
  
}


#Reboots netscaler
function reboot {

    $body = ConvertTo-JSON @{
        "reboot"=@{
            "warm" = $false;
            }
        }

    Invoke-RestMethod -uri "$hostname/nitro/v1/config/reboot" -body $body -WebSession $NSSession `
    -Headers @{"Content-Type"="application/json"} -Method POST|Out-Null
}
###Script starts here

#Logs into netscaler
write-host "Logging in..."
Login

#workaround for variable type
if($callhome)
{
   write-host "Enabling callhome"
   $ch = $true
}
else
{
    write-host "Disabling callhome"
    $ch = $false
}

write-host "Upgrading Netscaler $nsip..."
$timetorun = measure-command {upgradens $url $callhome}

write-host "Upgrade completed..." -ForegroundColor Green
write-host "Took $timetorun..."

if(!$noreboot)
{
write-host "Rebooting $nsip..."
reboot
}
else
{
write-host "Upgrade for $nsip completed. Make sure to reboot NS."
}


