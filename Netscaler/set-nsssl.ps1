<#PSScriptInfo

.VERSION 1.4

.GUID 2a8be02b-621b-46be-9f20-c373a3882927

.AUTHOR @ryan_c_butler

.AUTHOR Marco Hofmann @xenadmin (www.meinekleinefarm.net)

.COMPANYNAME Techdrabble.com

.COPYRIGHT 2016-2022

.TAGS Netscaler REST SSL A SSLLABS

.LICENSEURI https://github.com/ryancbutler/Citrix/blob/master/License.txt

.PROJECTURI https://github.com/ryancbutler/Citrix

.ICONURI 

.EXTERNALMODULEDEPENDENCIES 

.REQUIREDSCRIPTS 

.EXTERNALSCRIPTDEPENDENCIES 

.RELEASENOTES
03-17-16: Added port 3008 and 3009 to managment ips
03-28-16: Rewrite to reflect PS best practice and managment IP ciphers
06-13-16: Adjusted to reflect https://www.citrix.com/blogs/2016/06/09/scoring-an-a-at-ssllabs-com-with-citrix-netscaler-2016-update/. Also removed management IPS from default.  (Tested with 11.0 65.31)
06-14-16: Now supports HTTPS
07-02-16: Added "nosave" paramenter
03-11-17: Default SSL profile additions for 11.1 and greater
06-02-17: Changes for default profile and add for policy priority argument.  Also added some error handling
08-27-17: Formatting for PS Gallery
01-27-18: Adjustment for default profile version https://support.citrix.com/article/CTX205291
06-15-22: Updated cipher groups for an A+ at SSLlabs.com - Q2/2022 (Marco Hofmann @xenadmin)
04-04-23: Re-worked formatting. (Marco Hofmann @xenadmin)
04-04-23: NetScaler 13.1 doesn't know SSLv2 anymore, so trying to disable it throws errors. Commented out for now. (Marco Hofmann @xenadmin)

#> 

<#
.SYNOPSIS
   A PowerShell script for hardening Netscaler SSL IPs based off of SSL LABS
.DESCRIPTION
   A PowerShell script that enables TLS 1.2 and TLS 1.3, disables SSLv2, SSLv3, TLS1 and TLS 1.1, creates and binds Diffie-Hellman (DH) key, creates and binds "Strict Transport Security policy" and removes all other ciphers and binds cipher group mentioned in https://www.citrix.com/blogs/2015/05/22/scoring-an-a-at-ssllabs-com-with-citrix-netscaler-the-sequel/
.PARAMETER nsip
   DNS Name or IP of the Netscaler that needs to be configured. (MANDATORY)
.PARAMETER adminaccount
   Netscaler admin account (Default: nsroot)
.PARAMETER adminpassword
   Password for the Netscaler admin account (Default: nsroot)
.PARAMETER https
   Use HTTPS for communication
.PARAMETER ciphergroupname
    Cipher group name to search for (Default: "custom-ssllabs-cipher")
.PARAMETER rwactname
    ReWrite action name (Default: "act-sts-header")
.PARAMETER rwpolname
    ReWrite policy name (Default: "pol-sts-force")
.PARAMETER rwpolpri
    ReWrite policy bind priority (Default: 50)
.PARAMETER dhname
    DH Key to be used (Default: "dhkey2048.key")
.PARAMETER sslprofile
    SSL Profile to be used (11.1 or greater)(Default: "custom-ssllabs-profile")
.PARAMETER enablesslprof
    Enables SSL Default Profile (11.1 or greater)
.PARAMETER mgmt
    Perform changes on Netsclaer managment IP
.PARAMETER nolb
    Do not perform changes on Netscaler Load Balanced SSL VIPs
.PARAMETER nocsw
    Do not perform changes on Netscaler Content Switch VIPs
.PARAMETER novpn
    Do not perofm change on Netscaler VPN\Netscaler Gateway VIPs
.PARAMETER noneg
    Do not adjust SSL renegotiation
.PARAMETER nosave
    Do not save nsconfig at the end of the script
.EXAMPLE
    Defaults
   .\set-nsssl -nsip 10.1.1.2
.EXAMPLE
    Enables Default SSL profile and configures Netscaler (11.1 or greater) with defaults using SSL profiles
   .\set-nsssl -nsip 10.1.1.2 -enablesslprof
.EXAMPLE
    Uses HTTPs for NSIP communication
   .\set-nsssl -nsip 10.1.1.2 -https
.Example
    Only can be used for 11.1 and greater
   .\set-nsssl.ps1 -nsip 192.168.50 -ciphergroupname superciphergroup -sslprofile myssllabsprofile
.EXAMPLE
   .\set-nsssl -nsip 10.1.1.2 -adminaccount nsadmin -adminpassword "mysupersecretpassword" -ciphergroupname "mynewciphers" -rwactname "rw-actionnew" -rwpolname "rw-polnamenew" -dhname "mydhey.key" -mgmt -nocsw
   #>

   Param (
    [Parameter(Mandatory = $true)]$nsip,
    [String]$adminaccount = "nsroot",
    [String]$adminpassword = "nsroot",
    [switch]$https,
    [string]$ciphergroupname = "custom-ssllabs-cipher",   
    [string]$rwactname = "act-sts-header",
    [string]$rwpolname = "pol-sts-force",
    [string]$rwpolpri = "100",
    [string]$dhname = "dhkey2048.key",
    [string]$sslprofile = "custom-ssllabs-profile",
    [switch]$enablesslprof,
    [switch]$mgmt,
    [switch]$nolb,
    [switch]$nocsw,
    [switch]$novpn,
    [switch]$noneg,
    [switch]$nosave
)

#Netscaler NSIP login information
if ($https) {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls
    [System.Net.ServicePointManager]::ServerCertificateValidationCallback = { $true }
    write-host "Connecting HTTPS" -ForegroundColor Yellow
    $hostname = "https://" + $nsip
}
else {
    write-host "Connecting HTTP" -ForegroundColor Yellow
    $hostname = "http://" + $nsip
}

$username = $adminaccount
$password = $adminpassword

##Functions
###############################
#Probably not much you have to edit below this
###############################

#Many functions pulled from http://www.carlstalhood.com/netscaler-scripting/

function Login {

    # Login to NetScaler and save session to global variable
    $body = ConvertTo-JSON @{
        "login" = @{
            "username" = "$username";
            "password" = "$password"
        }
    }
    try {
        Invoke-RestMethod -uri "$hostname/nitro/v1/config/login" -body $body -SessionVariable NSSession `
            -Headers @{"Content-Type" = "application/vnd.com.citrix.netscaler.login+json" } -Method POST | Out-Null
        $Script:NSSession = $local:NSSession
    }
    Catch {
        throw $_
    }
}

function Cipher ($Name, $Cipher) {

    # Support function called by CipherGroup
    $body = @{
        "sslcipher_binding" = [ordered]@{
            "ciphergroupname" = "$Name";
            "ciphername"      = "$Cipher";
        }
    }
    $body = ConvertTo-JSON $body
    try {
        Invoke-RestMethod -uri "$hostname/nitro/v1/config/sslcipher_binding/$Name" -body $body -WebSession $NSSession `
            -Headers @{"Content-Type" = "application/vnd.com.citrix.netscaler.sslcipher_binding+json" } -Method PUT | Out-Null
    }
    catch {
        Write-Warning ($_.ErrorDetails | convertfrom-json).message
    }
}

function get-ciphers ($Name) {
    #Get cipher groups already on netscaler
    try {
        $ciphers = Invoke-RestMethod -uri "$hostname/nitro/v1/config/sslcipher" -WebSession $NSSession `
            -Headers @{"Content-Type" = "application/json" } -Method GET
    }
    catch {
        Write-Warning ($_.ErrorDetails | convertfrom-json).message
    }
    return $ciphers.sslcipher
}

function CipherGroup ($Name) {
    $body = @{
        "sslcipher" = @{
            "ciphergroupname" = "$Name";
        }
    }
    $body = ConvertTo-JSON $body
    try {
        Invoke-RestMethod -uri "$hostname/nitro/v1/config/sslcipher?action=add" -body $body -WebSession $NSSession `
            -Headers @{"Content-Type" = "application/vnd.com.citrix.netscaler.sslcipher+json" } -Method POST | Out-Null
    }
    catch {
        Write-Warning ($_.ErrorDetails | convertfrom-json).message
    }
    #feel free to edit these
    Cipher $Name TLS1.3-AES256-GCM-SHA384
    Cipher $Name TLS1.3-CHACHA20-POLY1305-SHA256
    Cipher $Name TLS1.3-AES128-GCM-SHA256
    Cipher $Name TLS1.2-ECDHE-ECDSA-AES128-GCM-SHA256
    Cipher $Name TLS1.2-ECDHE-ECDSA-AES256-GCM-SHA384
    Cipher $Name TLS1.2-ECDHE-ECDSA-AES128-SHA256
    Cipher $Name TLS1.2-ECDHE-ECDSA-AES256-SHA384
    Cipher $Name TLS1-ECDHE-ECDSA-AES128-SHA
    Cipher $Name TLS1-ECDHE-ECDSA-AES256-SHA
    Cipher $Name TLS1.2-ECDHE-RSA-AES128-GCM-SHA256
    Cipher $Name TLS1.2-ECDHE-RSA-AES256-GCM-SHA384
    Cipher $Name TLS1.2-ECDHE-RSA-AES-128-SHA256
    Cipher $Name TLS1.2-ECDHE-RSA-AES-256-SHA384
    Cipher $Name TLS1-ECDHE-RSA-AES128-SHA
    Cipher $Name TLS1-ECDHE-RSA-AES256-SHA
    Cipher $Name TLS1.2-DHE-RSA-AES128-GCM-SHA256
    Cipher $Name TLS1.2-DHE-RSA-AES256-GCM-SHA384
    Cipher $Name TLS1-DHE-RSA-AES-128-CBC-SHA
    Cipher $Name TLS1-DHE-RSA-AES-256-CBC-SHA
    Cipher $Name TLS1-AES-128-CBC-SHA
    Cipher $Name TLS1-AES-256-CBC-SHA
}

function CipherGroup-vpx ($Name) {
    $body = @{
        "sslcipher" = @{
            "ciphergroupname" = "$Name";
        }
    }
    $body = ConvertTo-JSON $body
    try {
        Invoke-RestMethod -uri "$hostname/nitro/v1/config/sslcipher?action=add" -body $body -WebSession $NSSession `
            -Headers @{"Content-Type" = "application/vnd.com.citrix.netscaler.sslcipher+json" } -Method POST | Out-Null
    }
    catch {
        Write-Warning ($_.ErrorDetails | convertfrom-json).message
    }
    #feel free to edit these
    Cipher $Name TLS1.3-AES256-GCM-SHA384
    Cipher $Name TLS1.3-CHACHA20-POLY1305-SHA256
    Cipher $Name TLS1.3-AES128-GCM-SHA256
    Cipher $Name TLS1.2-ECDHE-ECDSA-AES128-GCM-SHA256
    Cipher $Name TLS1.2-ECDHE-ECDSA-AES256-GCM-SHA384
    Cipher $Name TLS1.2-ECDHE-ECDSA-AES128-SHA256
    Cipher $Name TLS1.2-ECDHE-ECDSA-AES256-SHA384
    Cipher $Name TLS1-ECDHE-ECDSA-AES128-SHA
    Cipher $Name TLS1-ECDHE-ECDSA-AES256-SHA
    Cipher $Name TLS1.2-ECDHE-RSA-AES128-GCM-SHA256
    Cipher $Name TLS1.2-ECDHE-RSA-AES256-GCM-SHA384
    Cipher $Name TLS1.2-ECDHE-RSA-AES-128-SHA256
    Cipher $Name TLS1.2-ECDHE-RSA-AES-256-SHA384
    Cipher $Name TLS1-ECDHE-RSA-AES128-SHA
    Cipher $Name TLS1-ECDHE-RSA-AES256-SHA
    Cipher $Name TLS1.2-DHE-RSA-AES128-GCM-SHA256
    Cipher $Name TLS1.2-DHE-RSA-AES256-GCM-SHA384
    Cipher $Name TLS1-DHE-RSA-AES-128-CBC-SHA
    Cipher $Name TLS1-DHE-RSA-AES-256-CBC-SHA
    Cipher $Name TLS1-AES-128-CBC-SHA
    Cipher $Name TLS1-AES-256-CBC-SHA
}

function get-vpnservers {
    #gets netscaler gateway VIPs
    try {
        $vips = Invoke-RestMethod -uri "$hostname/nitro/v1/config/vpnvserver" -WebSession $NSSession `
            -Headers @{"Content-Type" = "application/json" } -Method GET
    }
    catch {
        Write-Warning ($_.ErrorDetails | convertfrom-json).message
    }
    return $vips.vpnvserver
}

function get-vservers {
    #gets load balancers
    try {
        $vips = Invoke-RestMethod -uri "$hostname/nitro/v1/config/lbvserver" -WebSession $NSSession `
            -Headers @{"Content-Type" = "application/json" } -Method GET
    }
    catch {
        Write-Warning ($_.ErrorDetails | convertfrom-json).message
    }    
    return $vips.lbvserver
}

function get-csservers {
    #gets content switches
    try {
        $vips = Invoke-RestMethod -uri "$hostname/nitro/v1/config/csvserver" -WebSession $NSSession `
            -Headers @{"Content-Type" = "application/json" } -Method GET
    }
    catch {
        Write-Warning ($_.ErrorDetails | convertfrom-json).message
    }
    return $vips.csvserver
}

function Logout {
    #logs out
    $body = ConvertTo-JSON @{
        "logout" = @{
        }
    }
    try {
        Invoke-RestMethod -uri "$hostname/nitro/v1/config/logout" -body $body -WebSession $NSSession `
            -Headers @{"Content-Type" = "application/vnd.com.citrix.netscaler.logout+json" } -Method POST | Out-Null
    }
    catch {
        Write-Warning ($_.ErrorDetails | convertfrom-json).message
    }
}

function set-cipher ($Name, $cipher) {
    #unbinds all cipher groups
    $foundflag = 0 #flag if cipher already found
    $cgs = Invoke-RestMethod -uri "$hostname/nitro/v1/config/sslvserver_sslciphersuite_binding/$Name" -WebSession $NSSession `
        -Headers @{"Content-Type" = "application/json" } -Method GET

    $cgs = $cgs.sslvserver_sslciphersuite_binding

    foreach ($cg in $cgs) {
        if ($cg.ciphername -notlike $cipher) {
            write-host "Unbinding" $cg.ciphername -ForegroundColor yellow
            try {
                Invoke-RestMethod -uri ("$hostname/nitro/v1/config/sslvserver_sslciphersuite_binding/$Name" + "?args=cipherName:" + $cg.ciphername ) -WebSession $NSSession `
                    -Headers @{"Content-Type" = "application/vnd.com.citrix.netscaler.sslvserver_sslciphersuite_binding+json" } -Method DELETE | Out-Null
            }
            catch {
                Write-Warning ($_.ErrorDetails | convertfrom-json).message
            }
        }
        else {
            write-host $cipher "already present.." -ForegroundColor Green
            $foundflag = 1
        }
    }

    #Make sure SSL profile not in use
    if ($useprofile -eq $false) {
        if ($foundflag -eq 0) {
            #binds new cipher group created if not already present
            write-host "Binding $cipher" -ForegroundColor Yellow
            $body = ConvertTo-JSON @{
                "sslvserver_sslciphersuite_binding" = @{
                    "vservername" = "$Name";
                    "ciphername"  = "$Cipher";
                }
            }
            try {
                Invoke-RestMethod -uri "$hostname/nitro/v1/config/sslvserver_sslciphersuite_binding/$Name" -body $body -WebSession $NSSession `
                    -Headers @{"Content-Type" = "application/vnd.com.citrix.netscaler.sslvserver_sslciphersuite_binding+json" } -Method PUT | Out-Null
            }
            catch {
                Write-Warning ($_.ErrorDetails | convertfrom-json).message
            }
        }
    
        #disables sslv2, sslv3, tls1 and tls11
        $body = ConvertTo-JSON @{
            "sslvserver" = @{
                "vservername" = "$Name";
                "tls13"       = "ENABLED";
                "tls12"       = "ENABLED";
                "tls11"       = "DISABLED";
                "tls1"        = "DISABLED";
                "ssl3"        = "DISABLED";
                # "ssl2"        = "DISABLED";
                "dh"          = "ENABLED";
                "dhfile"      = $dhname;
            }
        }
        try {
            Invoke-RestMethod -uri "$hostname/nitro/v1/config/sslvserver/$Name" -body $body -WebSession $NSSession `
                -Headers @{"Content-Type" = "application/vnd.com.citrix.netscaler.sslvserver+json" } -Method PUT | Out-Null
        }
        catch {
            Write-Warning ($_.ErrorDetails | convertfrom-json).message
        }
    }
}

function set-nscipher ($Name, $cipher) {
    #unbinds all cipher groups
    $foundflag = 0 #flag if cipher already found
    $cgs = Invoke-RestMethod -uri "$hostname/nitro/v1/config/sslservice_sslciphersuite_binding/$Name" -WebSession $NSSession `
        -Headers @{"Content-Type" = "application/json" } -Method GET
    $cgs = $cgs.sslservice_sslciphersuite_binding

    foreach ($cg in $cgs) {
        if ($cg.ciphername -notlike $cipher) {
            write-host "Unbinding" $cg.ciphername -ForegroundColor yellow
            try {
                Invoke-RestMethod -uri ("$hostname/nitro/v1/config/sslservice_sslciphersuite_binding/$Name" + "?args=cipherName:" + $cg.ciphername ) -WebSession $NSSession `
                    -Headers @{"Content-Type" = "application/vnd.com.citrix.netscaler.sslservice_sslciphersuite_binding+json" } -Method DELETE | Out-Null
            }
            catch {
                Write-Warning ($_.ErrorDetails | convertfrom-json).message
            }
        }
        else {
            write-host $cipher "already present.." -ForegroundColor Green
            $foundflag = 1
        }
    }

    if ($foundflag -eq 0) {
        #binds new cipher group created if not already present
        write-host "Binding $cipher" -ForegroundColor Yellow
        $body = ConvertTo-JSON @{
            "sslservice_sslciphersuite_binding" = @{
                "servicename" = "$Name";
                "ciphername"  = "$Cipher";
            }
        }
        try {
            Invoke-RestMethod -uri "$hostname/nitro/v1/config/sslservice_sslciphersuite_binding/$Name" -body $body -WebSession $NSSession `
                -Headers @{"Content-Type" = "application/vnd.com.citrix.netscaler.sslservice_sslciphersuite_binding+json" } -Method PUT | Out-Null
        }
        catch {
            Write-Warning ($_.ErrorDetails | convertfrom-json).message
        }       
    }
}

function set-nsip {
    #Adjusts SSL setting for IPV4 and IPV6 on 443
    $services = Invoke-RestMethod -uri "$hostname/nitro/v1/config/sslservice" -WebSession $NSSession `
        -Headers @{"Content-Type" = "application/json" } -Method GET
    $services = $services.sslservice

    #only want nshttps services
    $nsips = $services | Where-Object { ($_.servicename -like "nshttps-*") -or ($_.servicename -like "nskrpcs-*") -or ($_.servicename -like "nsrpcs-*") }
    foreach ($nsip in $nsips) {
        $name = $nsip.servicename
        write-host $name
        if ($useprofile) {
            #Assigning SSL Profile and disabling SSLv3
            $body = ConvertTo-JSON @{
                "sslservice" = @{
                    "servicename" = "$Name";
                    "sslprofile"  = $sslprofile;
                    "tls11"       = "DISABLED";
                    "tls1"        = "DISABLED";
                    "ssl3"        = "DISABLED";
                    # "ssl2"        = "DISABLED";
                }
            }
            try {
                Invoke-RestMethod -uri "$hostname/nitro/v1/config/sslservice/$Name" -body $body -WebSession $NSSession `
                    -Headers @{"Content-Type" = "application/json" } -Method PUT | Out-Null
            }
            catch {
                Write-Warning ($_.ErrorDetails | convertfrom-json).message
            }
        }
        else {
            #No SSL Profile
            $body = ConvertTo-JSON @{
                "sslservice" = @{
                    "servicename" = "$Name";
                    "tls13"       = "ENABLED";
                    "tls12"       = "ENABLED";
                    "tls11"       = "DISABLED";
                    "tls1"        = "DISABLED";
                    "ssl3"        = "DISABLED";
                    # "ssl2"        = "DISABLED";
                    "dh"          = "ENABLED";
                    "dhfile"      = $dhname;
                }
            }
            try {
                Invoke-RestMethod -uri "$hostname/nitro/v1/config/sslservice/$Name" -body $body -WebSession $NSSession `
                    -Headers @{"Content-Type" = "application/vnd.com.citrix.netscaler.sslservice+json" } -Method PUT | Out-Null               
            }
            catch {
                Write-Warning ($_.ErrorDetails | convertfrom-json).message
            }
            set-nscipher $name $ciphergroupname
        }
    }
}

function set-sslprofilebind ($name, $sslprofile) {
    #Sets SSL Profile and disables SSLv3
    $body = ConvertTo-JSON @{
        "sslvserver" = @{
            "vservername" = "$Name";
            "sslprofile"  = $sslprofile;
            "tls11"       = "DISABLED";
            "tls1"        = "DISABLED";
            "ssl3"        = "DISABLED";
            # "ssl2"        = "DISABLED";
        }
    }
    try {
        Invoke-RestMethod -uri "$hostname/nitro/v1/config/sslvserver/$Name" -body $body -WebSession $NSSession `
            -Headers @{"Content-Type" = "application/json" } -Method PUT | Out-Null
    }
    catch {
        Write-Warning ($_.ErrorDetails | convertfrom-json).message
    }
}

function SaveConfig {
    #Saves NS config
    $body = ConvertTo-JSON @{
        "nsconfig" = @{
        }
    }
    try {
        Invoke-RestMethod -uri "$hostname/nitro/v1/config/nsconfig?action=save" -body $body -WebSession $NSSession `
            -Headers @{"Content-Type" = "application/vnd.com.citrix.netscaler.nsconfig+json" } -Method POST | Out-Null
    }
    catch {
        Write-Warning ($_.ErrorDetails | convertfrom-json).message
    }
}

function get-rewritepol {
    #gets rewrite policies
    try {
        $pols = Invoke-RestMethod -uri "$hostname/nitro/v1/config/rewritepolicy" -WebSession $NSSession `
            -Headers @{"Content-Type" = "application/json" } -Method GET
    }
    catch {
        Write-Warning ($_.ErrorDetails | convertfrom-json).message
    }
    return $pols.rewritepolicy
}

function EnableFeature ($feature) {
    #enables NS feature
    $body = @{
        "nsfeature" = @{
            "feature" = $feature;
        }
    }
    $body = ConvertTo-JSON $body
    try {
        Invoke-RestMethod -uri "$hostname/nitro/v1/config/nsfeature?action=enable" -body $body -WebSession $NSSession `
            -Headers @{"Content-Type" = "application/vnd.com.citrix.netscaler.nsfeature+json" } -Method POST | Out-Null
    }
    catch {
        Write-Warning ($_.ErrorDetails | convertfrom-json).message
    }
}

Function SetupSTS ($rwactname, $rwpolname) {
    # Strict Transport Security Policy creation

    EnableFeature Rewrite

    $body = ConvertTo-JSON @{
        "rewriteaction" = @{
            "name"              = $rwactname;
            "type"              = "insert_http_header";
            "target"            = "Strict-Transport-Security";
            "stringbuilderexpr" = '"max-age=157680000"';
        }
    }
    try {
        Invoke-RestMethod -uri "$hostname/nitro/v1/config/rewriteaction?action=add" -body $body -WebSession $NSSession `
            -Headers @{"Content-Type" = "application/vnd.com.citrix.netscaler.rewriteaction+json" } -Method POST | Out-Null
    }
    catch {
        Write-Warning ($_.ErrorDetails | convertfrom-json).message
    }

    $body = ConvertTo-JSON @{
        "rewritepolicy" = @{
            "name"   = $rwpolname;
            "action" = $rwactname;
            "rule"   = 'true';
        }
    }
    try {
        Invoke-RestMethod -uri "$hostname/nitro/v1/config/rewritepolicy?action=add" -body $body -WebSession $NSSession `
            -Headers @{"Content-Type" = "application/vnd.com.citrix.netscaler.rewritepolicy+json" } -Method POST | Out-Null
    }
    catch {
        Write-Warning ($_.ErrorDetails | convertfrom-json).message
    }
}

Function set-lbpols ($vip, $rwpolname, $rwpolpri) {
    #binds LB policy
    $name = $vip.name

    $body = ConvertTo-JSON @{
        "lbvserver_rewritepolicy_binding" = @{
            "name"       = $Name;
            "policyname" = $rwpolname;
            "priority"   = $rwpolpri;
            "bindpoint"  = "RESPONSE";
        }
    }
    try {
        Invoke-RestMethod -uri "$hostname/nitro/v1/config/lbvserver_rewritepolicy_binding/$Name" -body $body -WebSession $NSSession `
            -Headers @{"Content-Type" = "application/vnd.com.citrix.netscaler.lbvserver_rewritepolicy_binding+json" } -Method POST | Out-Null
    }
    catch {
        Write-Warning ($_.ErrorDetails | convertfrom-json).message
    }
}

Function set-cspols ($vip, $rwpolname, $rwpolpri) {
    #binds CS policy
    $name = $vip.name

    $body = ConvertTo-JSON @{
        "csvserver_rewritepolicy_binding" = @{
            "name"       = $Name;
            "policyname" = $rwpolname;
            "priority"   = $rwpolpri;
            "bindpoint"  = "RESPONSE";
        }
    }
    try {
        Invoke-RestMethod -uri "$hostname/nitro/v1/config/csvserver_rewritepolicy_binding/$Name" -body $body -WebSession $NSSession `
            -Headers @{"Content-Type" = "application/vnd.com.citrix.netscaler.csvserver_rewritepolicy_binding+json" } -Method PUT | Out-Null
    }
    catch {
        Write-Warning ($_.ErrorDetails | convertfrom-json).message
    }
}

Function set-vpnpols ($vip, $rwpolname, $rwpolpri) {
    #binds NG policy
    $name = $vip.name

    $body = ConvertTo-JSON @{
        "vpnvserver_rewritepolicy_binding" = @{
            "name"                   = $Name;
            "policy"                 = $rwpolname;
            "priority"               = $rwpolpri;
            "gotopriorityexpression" = "END";
            "bindpoint"              = "RESPONSE";
        }
    }
    try {
        Invoke-RestMethod -uri "$hostname/nitro/v1/config/vpnvserver_rewritepolicy_binding/$Name" -body $body -WebSession $NSSession `
            -Headers @{"Content-Type" = "application/vnd.com.citrix.netscaler.vpnvserver_rewritepolicy_binding+json" } -Method POST | Out-Null
    }
    catch {
        Write-Warning ($_.ErrorDetails | convertfrom-json).message
    }
}

function checkvpx {
    #Checks if NS is a VPX or not
    $info = Invoke-RestMethod -uri "$hostname/nitro/v1/config/nshardware" -WebSession $NSSession `
        -Headers @{"Content-Type" = "application/json" } -Method GET
    $info = $info.nshardware
    if ($info.hwdescription -like "NetScaler Virtual Appliance") {
        write-host "VPX FOUND..." -ForegroundColor Gray
        $found = $true
    }
    else {
        $found = $false
    }
    Return $found
}

function new-dhkey ($name) {
    #Creates new DH Key
    $body = @{
        "ssldhparam" = @{
            "dhfile" = $name;
            "bits"   = "2048";
            "gen"    = "2";
        }
    }
    $body = ConvertTo-JSON $body
    Invoke-RestMethod -uri "$hostname/nitro/v1/config/ssldhparam?action=create" -body $body -WebSession $NSSession `
        -Headers @{"Content-Type" = "application/json" } -Method POST -TimeoutSec 600
}

function checkfordhkey ($dhname) {
    #Checks if DHKEY is present
    $urlstring = "$hostname" + "/nitro/v1/config/systemfile/" + $dhname + "?args=filelocation:%2Fnsconfig%2Fssl"
    try {
        $info = Invoke-RestMethod -uri $urlstring -WebSession $NSSession `
            -Headers @{"Content-Type" = "application/json" } -Method GET
        $msg = $info.message
    }
    Catch {
        $ErrorMessage = $_.Exception.Response
        $FailedItem = $_.Exception.ItemName
    }
    if ($msg -like "Done") {
        write-host "DHKEY alredy present..." -ForegroundColor Green
        $found = $true
    }
    else {
        write-host "DHKEY NOT present..." -ForegroundColor Yellow
        $found = $false
    }
    Return $found
}

Function set-sslparams {
    #Allow secure renegotiation
    $body = ConvertTo-JSON @{
        "sslparameter" = @{
            "denysslreneg" = "FRONTEND_CLIENT";
        }
    }
    Invoke-RestMethod -uri "$hostname/nitro/v1/config/sslparameter/" -body $body -WebSession $NSSession `
        -Headers @{"Content-Type" = "application/json" } -Method PUT | Out-Null
}

Function enable-sslprof {
    #Enables default SSL profile https://docs.citrix.com/en-us/netscaler/11-1/ssl/ssl-profiles1/ssl-enabling-the-default-profile.html 
    $body = ConvertTo-JSON @{
        "sslparameter" = @{
            "defaultprofile" = "ENABLED";
        }
    }
    Invoke-RestMethod -uri "$hostname/nitro/v1/config/sslparameter/" -body $body -WebSession $NSSession `
        -Headers @{"Content-Type" = "application/json" } -Method PUT | Out-Null
}

function check-nsversion {
    #Checks for supported NS version
    $info = Invoke-RestMethod -uri "$hostname/nitro/v1/config/nsversion" -WebSession $NSSession `
        -Headers @{"Content-Type" = "application/json" } -Method GET
    $version = $info.nsversion.version
    [regex]$majorreg = "(?<=NS).*?(?=:)"
    [regex]$minorreg = "(?<=Build ).*?(?=.n)"
    [version]$version = ($majorreg.match($version)).value + "." + ($minorreg.match($version)).value

    return $version
}

function check-defaultprofile {
    #Checks for SSL default profile
    $info = Invoke-RestMethod -uri "$hostname/nitro/v1/config/sslparameter" -WebSession $NSSession `
        -Headers @{"Content-Type" = "application/json" } -Method GET 
    return $info.sslparameter.defaultprofile
}

function check-sslprofile ($sslprofile) {  
    try {   
        #Checks for SSL default profile
        $info = Invoke-RestMethod -uri "$hostname/nitro/v1/config/sslprofile/$sslprofile" -WebSession $NSSession `
            -Headers @{"Content-Type" = "application/json" } -Method GET 
    }
    catch {
        $ErrorMessage = $_.Exception.Response
        $FailedItem = $_.Exception.ItemName
    }

    if ($info.sslprofile) {
        write-host "Found SSL PROFILE $sslprofile" -ForegroundColor Green
        $found = $true
    }
    else {
        write-host "SSL PROFILE NOT present..." -ForegroundColor Yellow
        $found = $false
    }

    Return $found
}

function new-sslprofile ($sslprofile, $dhname) {
    $body = ConvertTo-JSON @{
        "sslprofile" = @{
            "name"                      = $sslprofile;
            "sslprofiletype"            = "FrontEnd";
            "dh"                        = "ENABLED";
            "dhcount"                   = "0";
            "dhfile"                    = $dhname;
            "ersa"                      = "ENABLED";
            "ersacount"                 = "0";
            "sessreuse"                 = "ENABLED";
            "sesstimeout"               = "120";
            "cipherredirect"            = "DISABLED";
            "clientauth"                = "DISABLED";
            "sslredirect"               = "DISABLED";
            "redirectportrewrite"       = "DISABLED";
            "nonfipsciphers"            = "DISABLED";
            # "ssl2"                      = "DISABLED";
            "ssl3"                      = "DISABLED";
            "tls1"                      = "DISABLED";
            "tls11"                     = "DISABLED";
            "tls12"                     = "ENABLED";
            "tls13"                     = "ENABLED";
            "snienable"                 = "DISABLED";
            "ocspstapling"              = "DISABLED";
            "serverauth"                = "DISABLED";
            "pushenctrigger"            = "Always";
            "sendclosenotify"           = "YES";
            "insertionencoding"         = "Unicode";
            "denysslreneg"              = "FRONTEND_CLIENT";
            "quantumsize"               = "8192";
            "strictcachecks"            = "NO";
            "encrypttriggerpktcount"    = "45";
            "pushflag"                  = "0";
            "dropreqwithnohostheader"   = "NO";
            "pushenctriggertimeout"     = "1";
            "ssltriggertimeout"         = "100";
            "clientauthuseboundcachain" = "DISABLED";
            "sessionticket"             = "DISABLED";
            "sessionticketlifetime"     = "300";
        }
    }
    Invoke-RestMethod -uri "$hostname/nitro/v1/config/sslprofile" -body $body -WebSession $NSSession -Headers @{"Content-Type" = "application/json" } -Method POST | Out-Null
}

function set-profilecipherbinding ($name, $cipher) {
    write-host "Binding $cipher" -ForegroundColor Yellow
    $body = ConvertTo-JSON @{
        "sslprofile_sslcipher_binding" = @{
            "name"       = "$Name";
            "ciphername" = "$Cipher";
        }
    }
    Invoke-RestMethod -uri "$hostname/nitro/v1/config/sslprofile_sslcipher_binding/$Name" -body $body -WebSession $NSSession `
        -Headers @{"Content-Type" = "application/json" } -Method PUT | Out-Null
}

function set-profilecipher ($name, $cipher) {
    #unbinds all cipher groups
    $foundflag = 0 #flag if cipher already found
    $cgs = Invoke-RestMethod -uri "$hostname/nitro/v1/config/sslprofile_sslcipher_binding/$name" -WebSession $NSSession `
        -Headers @{"Content-Type" = "application/json" } -Method GET
    $cgs = $cgs.sslprofile_sslcipher_binding

    #Check for cipher
    $found = 0
    foreach ($cg in $cgs) {
        if ($cg.cipheraliasname -like $cipher) {
            Write-Host "Cipher Present"
            $found = 1
        }
    }

    if ($found -eq 0) {
        #binds new cipher group created if not already present
        set-profilecipherbinding -name $name -cipher $cipher
    }

    #Remove other ciphers
    foreach ($cg in $cgs) {
        if ($cg.cipheraliasname -notlike $cipher) {
            write-host "Unbinding" $cg.cipheraliasname -ForegroundColor yellow
            Invoke-RestMethod -uri ("$hostname/nitro/v1/config/sslprofile_sslcipher_binding/$Name" + "?args=cipherName:" + $cg.cipheraliasname ) -WebSession $NSSession `
                -Headers @{"Content-Type" = "application/vnd.com.citrix.netscaler.sslservice_sslciphersuite_binding+json" } -Method DELETE | Out-Null
        }
    }
}

###Script starts here

#Logs into netscaler
write-host "Logging in..."
Login

#Checks for supported NS firmware version (10.5)
$version = check-nsversion
switch ($version) {
    { $_ -lt 10.5 } {
        throw "Netscaler firmware version MUST be greater than 10.5"
        exit
    }
    { $_ -lt "11.0.64.34" } {
        write-host "$($version.ToString()) has been detected. Default SSL profile not supported."
        $useprofile = $false
        if ($sslprofile -notlike "custom-ssllabs-profile" -or $enablesslprof) {
            Write-Host "SSL PROFILE IGNORED DUE TO FIRMARE VERSION" -ForegroundColor Yellow
        }
    }
    { $_ -ge "11.0.64.34" } {
        write-host "$($version.ToString()) has been detected. Default SSL profile supported."
                
        #Check for SSL default profile. Might do something around legacy in the future
        $testprof = check-defaultprofile
        if ($testprof -like "ENABLED") {
            write-host "DEFAULT SSL PROFILE IS ENABLED." -ForegroundColor GREEN
            $useprofile = $true
        }
        elseif ($testprof -like "DISABLED" -and $enablesslprof) {
            write-host "Enabling Default Profile Feature" -ForegroundColor Gray
            $useprofile = $true
            enable-sslprof
        }
        else {
            Clear-Host
            write-host '"Default SSL Profile" is recommended for 11.0.64.34 or greater.  Running in LEGACY mode for this run.' -ForegroundColor Yellow
            write-host 'See https://docs.citrix.com/en-us/netscaler/11-1/ssl/ssl-profiles1/ssl-enabling-the-default-profile.html' -ForegroundColor yellow
            write-host 'Can enable with the -enablesslprof switch OR manually' -ForegroundColor Yellow
            write-host 'CLI: set ssl parameter -defaultProfile ENABLED' -ForegroundColor Yellow
            write-host 'GUI: Traffic Management > SSL > Change advanced SSL settings, scroll down, and select Enable Default Profile.' -ForegroundColor Yellow
            Start-Sleep -Seconds 5
            $useprofile = $false
        }
    }
}
    
write-host "Checking for DHKEY: " $dhname  -ForegroundColor White
#Checks for and creates DH key
if ((checkfordhkey $dhname) -eq $false) {
    write-host "DHKEY creation in process.  Can take a couple of minutes..." -ForegroundColor yellow
    new-dhkey $dhname
}

write-host "Checking for cipher group..." -ForegroundColor White
#Checks for cipher group we will be creating    
if (((get-ciphers).ciphergroupname) -notcontains $ciphergroupname) {
    write-host "Creating" $ciphergroupname -ForegroundColor Gray
    if (checkvpx) {
        write-host "Creating cipher group for VPX..."
        CipherGroup-vpx $ciphergroupname
    }
    else {
        write-host "Creating cipher group for NON-VPX..."
        ciphergroup $ciphergroupname
    }
}
else {
    write-host $ciphergroupname "already present" -ForegroundColor Green
}

write-host "Checking for rewrite policy..." -ForegroundColor White
#Checks for rewrite policy
if (((get-rewritepol).name) -notcontains $rwpolname) {
    write-host "Creating " $rwpolname -ForegroundColor Gray
    SetupSTS $rwactname $rwpolname
}
else {
    write-host $rwpolname "already present" -ForegroundColor Green
}

#Checking for SSL profile and creating if needed
if ($useprofile) {
    write-host "Checking for SSL Profile..." -ForegroundColor White
    if ((check-sslprofile -sslprofile $sslprofile) -eq $false) {
        write-host "Creating SSL Profile $sslprofile" -ForegroundColor Gray
        new-sslprofile $sslprofile $dhname
        write-host "Binding Cipher Group" -ForegroundColor Gray
        set-profilecipher $sslprofile $ciphergroupname
    }
}


if ($mgmt) {
    write-host "Adjusting SSL managment IPs..." -ForegroundColor White
    #adjusts all managment IPs.  Does not adjust ciphers
    set-nsip
}
else {
    write-host "Skipping SSL managment IPs..."
}

if ($nolb) {
    write-host "Skipping LB VIPs..." -ForegroundColor White
}
else {
    write-host "Checking LB VIPs..." -ForegroundColor White
    #Gets all LB servers that are SSL and makes changes
    $lbservers = (get-vservers)
    $ssls = $lbservers | Where-Object { $_.servicetype -like "SSL" }
    
    foreach ($ssl in $ssls) {
        write-host $ssl.name
            (set-cipher $ssl.name $ciphergroupname)
        if ($useprofile) {
            set-sslprofilebind $ssl.name $sslprofile
        }
        write-host "Binding STS policy"
        set-lbpols $ssl $rwpolname $rwpolpri
    }
}

if ($novpn) {
    write-host "Skiping VPN VIPS..."
}
else {
    write-host "Checking VPN VIPs..." -ForegroundColor White
    #Gets all Netscaler Gateways and makes changes
    $vpnservers = get-vpnservers
    
    foreach ($ssl in $vpnservers) {
        write-host $ssl.name
        if ($useprofile) {
            set-sslprofilebind $ssl.name $sslprofile
        }
        (set-cipher $ssl.name $ciphergroupname)
        write-host "Binding STS policy"
        set-vpnpols $ssl $rwpolname $rwpolpri
    }
}

if ($nocsw) {
    write-host "Skipping CSW IPs..." -ForegroundColor White
}
else {
    write-host "Checking CS VIPs..." -ForegroundColor White
    #Gets all Content Switches and makes changes
    $csservers = get-csservers
    #Filters for only SSL
    $csssls = $csservers | Where-Object { $_.servicetype -like "SSL" }
    foreach ($sslcs in $csssls) {
        write-host $sslcs.name
        if ($useprofile) {
            set-sslprofilebind $sslcs.name $sslprofile
        }
       (set-cipher $sslcs.name $ciphergroupname)
        write-host "Binding STS policy"
        set-cspols $sslcs $rwpolname $rwpolpri
    }
}

#SSL Global Params
if ($noneg -or $useprofile -eq $true) {
    write-host "Skipping SSL global renegotiation..." -ForegroundColor White
}
else {
    write-host "Setting SSL global renegotiation..."  -ForegroundColor White
    set-sslparams
}

#Save config
if ($nosave) {
    write-host "NOT saving NS config.." -ForegroundColor White
}
else {
    write-host "Saving NS config.." -ForegroundColor White
    #Save NS Config
    SaveConfig
}

write-host "Logging out..." -ForegroundColor White
#Logout
Logout