#Disables SSLv2 and SSLv3, removes default ciphers and binds ciphers mentioned in https://www.citrix.com/blogs/2015/05/22/scoring-an-a-at-ssllabs-com-with-citrix-netscaler-the-sequel/
#Checks for all SSL LB servers, content switches and Netscaler Gateways
#Version 1.0
#Tested with Windows 10 and Netscaler 11 60.63.16
#USE AT OWN RISK
#By: Ryan Butler 2-19-16

#Netscaler NSIP login information
$hostname = "http://192.168.100.50"
$username = "nsroot"
$password = "nsroot"

#what would you like to name the cipher group
$ciphergroupname = "claus-cipher-list-with-gcm"


##Functions
###############################
#Probably not much you have to edit below this
###############################

#Many functions pulled from http://www.carlstalhood.com/netscaler-scripting/


function Login {

    # Login to NetScaler and save session to global variable
    $body = ConvertTo-JSON @{
        "login"=@{
            "username"="$username";
            "password"="$password"
            }
        }
    Invoke-RestMethod -uri "$hostname/nitro/v1/config/login" -body $body -SessionVariable NSSession `
    -Headers @{"Content-Type"="application/vnd.com.citrix.netscaler.login+json"} -Method POST
    $Script:NSSession = $local:NSSession
}

function Cipher ($Name, $Cipher) {

    # Support function called by CipherGroup
    $body = @{
        "sslcipher_binding"=[ordered]@{
            "ciphergroupname"="$Name";
            "ciphername"="$Cipher";
            }
        }
    $body = ConvertTo-JSON $body
    Invoke-RestMethod -uri "$hostname/nitro/v1/config/sslcipher_binding/$Name" -body $body -WebSession $NSSession `
    -Headers @{"Content-Type"="application/vnd.com.citrix.netscaler.sslcipher_binding+json"} -Method PUT
}

function get-ciphers ($Name) {
    #Get cipher groups already on netscaler
    $body = @{
        "sslcipher_binding"=[ordered]@{
            "ciphergroupname"="$Name";
            "ciphername"="$Cipher";
            }
        }
    Invoke-RestMethod -uri "$hostname/nitro/v1/config/sslcipher" -WebSession $NSSession `
    -Headers @{"Content-Type"="application/json"} -Method GET
}

function CipherGroup ($Name) {
    #Ciphers from https://www.citrix.com/blogs/2015/05/22/scoring-an-a-at-ssllabs-com-with-citrix-netscaler-the-sequel/
    $body = @{
        "sslcipher"=@{
            "ciphergroupname"="$Name";
            }
        }
    $body = ConvertTo-JSON $body
    Invoke-RestMethod -uri "$hostname/nitro/v1/config/sslcipher?action=add" -body $body -WebSession $NSSession `
    -Headers @{"Content-Type"="application/vnd.com.citrix.netscaler.sslcipher+json"} -Method POST
    #feel free to edit these
    Cipher $Name TLS1.2-ECDHE-RSA-AES256-GCM-SHA384
    Cipher $Name TLS1.2-ECDHE-RSA-AES128-GCM-SHA256
    Cipher $Name TLS1.2-ECDHE-RSA-AES-128-SHA256
    Cipher $Name TLS1-ECDHE-RSA-AES256-SHA
    Cipher $Name TLS1-ECDHE-RSA-AES128-SHA
    Cipher $Name TLS1.2-DHE-RSA-AES256-GCM-SHA384
    Cipher $Name TLS1.2-DHE-RSA-AES128-GCM-SHA256
    Cipher $Name TLS1-DHE-RSA-AES-128-CBC-SHA
    Cipher $Name TLS1-AES-256-CBC-SHA
    Cipher $Name TLS1-AES-128-CBC-SHA
    Cipher $Name SSL3-DES-CBC3-SHA
}

function get-vpnservers{
    #gets netscaler gateway VIPs
    $vips = Invoke-RestMethod -uri "$hostname/nitro/v1/config/vpnvserver" -WebSession $NSSession `
    -Headers @{"Content-Type"="application/json"} -Method GET
    return $vips.vpnvserver
}

function get-vservers {
    #gets load balancers
    $vips = Invoke-RestMethod -uri "$hostname/nitro/v1/config/lbvserver" -WebSession $NSSession `
    -Headers @{"Content-Type"="application/json"} -Method GET
    return $vips.lbvserver
}

function get-csservers {
    #gets content switches
    $vips = Invoke-RestMethod -uri "$hostname/nitro/v1/config/csvserver" -WebSession $NSSession `
    -Headers @{"Content-Type"="application/json"} -Method GET
    return $vips.csvserver
}

function Logout {
    #logs out
    $body = ConvertTo-JSON @{
        "logout"=@{
            }
        }
    Invoke-RestMethod -uri "$hostname/nitro/v1/config/logout" -body $body -WebSession $NSSession `
    -Headers @{"Content-Type"="application/vnd.com.citrix.netscaler.logout+json"} -Method POST
}

function set-cipher ($Name, $cipher){
    #unbinds default cipher group
    Invoke-RestMethod -uri ("$hostname/nitro/v1/config/sslvserver_sslciphersuite_binding/$Name" + "?args=cipherName:DEFAULT") -WebSession $NSSession `
    -Headers @{"Content-Type"="application/vnd.com.citrix.netscaler.sslvserver_sslciphersuite_binding+json"} -Method DELETE

    #binds new cipher group created
    $body = ConvertTo-JSON @{
        "sslvserver_sslciphersuite_binding"=@{
            "vservername"="$Name";
            "ciphername"="$Cipher";
            }
        }
    Invoke-RestMethod -uri "$hostname/nitro/v1/config/sslvserver_sslciphersuite_binding/$Name" -body $body -WebSession $NSSession `
    -Headers @{"Content-Type"="application/vnd.com.citrix.netscaler.sslvserver_sslciphersuite_binding+json"} -Method PUT

    #disables sslv2 and sslv3
    $body = ConvertTo-JSON @{
        "sslvserver"=@{
            "vservername"="$Name";
            "ssl3"="DISABLED";
            "ssl2"="DISABLED";
            }
        }
    Invoke-RestMethod -uri "$hostname/nitro/v1/config/sslvserver/$Name" -body $body -WebSession $NSSession `
    -Headers @{"Content-Type"="application/vnd.com.citrix.netscaler.sslvserver+json"} -Method PUT
}

function SaveConfig {
    #Saves NS config
    $body = ConvertTo-JSON @{
        "nsconfig"=@{
            }
        }
    Invoke-RestMethod -uri "$hostname/nitro/v1/config/nsconfig?action=save" -body $body -WebSession $NSSession `
    -Headers @{"Content-Type"="application/vnd.com.citrix.netscaler.nsconfig+json"} -Method POST
}

###Script starts here
CLS
#Logs into netscaler
write-host "Logging in..."
Login|Out-Null
write-host "Logged in..."

write-host "Checking for cipher group..."
#Checks for cipher group we will be creating    
    if (((get-ciphers).sslcipher.ciphergroupname) -notcontains $ciphergroupname)
    {
        write-host "Creating " $ciphergroupname
        ciphergroup $ciphergroupname
    }
    else
    {
    write-host $ciphergroupname " already present"
    }

write-host "Checking LB VIPs..."
#Gets all LB servers that are SSL and makes changes
$lbservers = (get-vservers)
$ssls = $lbservers|where{$_.servicetype -like "SSL"}
foreach ($ssl in $ssls){
    write-host $ssl.name
    (set-cipher $ssl.name $ciphergroupname).message
}

write-host "Checking NG VIPs..."
#Gets all Netscaler Gateways and makes changes
$vpnservers = get-vpnservers
foreach ($ssl in $vpnservers){
    write-host $ssl.name
    (set-cipher $ssl.name $ciphergroupname).message
}

write-host "Checking NS VIPs..."
#Gets all Content Switches and makes changes
$csservers = get-csservers
#Filters for only SSL
$csssls = $csservers|where{$_.servicetype -like "SSL"}
foreach ($sslcs in $csssls){
    write-host $sslcs.name
    (set-cipher $sslcs.name $ciphergroupname).message
}

write-host "Saving NS config.."
#Save NS Config
SaveConfig|Out-Null

write-host "Logging out..."
#Logout
Logout|Out-Null

