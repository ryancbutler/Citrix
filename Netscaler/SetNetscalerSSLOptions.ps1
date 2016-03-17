#Disables SSLv2 and SSLv3, creates and binds DH key, removes all other ciphers and binds ciphers mentioned in https://www.citrix.com/blogs/2015/05/22/scoring-an-a-at-ssllabs-com-with-citrix-netscaler-the-sequel/
#Checks for NSIP, all SSL LB servers, content switches and Netscaler Gateways
#Version 2.1
#Tested with Windows 10 and Netscaler 11 60.63.16
#USE AT OWN RISK
#By: Ryan Butler 2-19-16
#3-17-16: Added port 3008 and 3009 to managment ips

#Netscaler NSIP login information
$hostname = "http://192.168.1.50"
$username = "nsroot"
$password = "nsroot"

#what would you like to name the cipher group
$ciphergroupname = "claus-cipher-list-with-gcm"

#Rewrite Policy names
$rwactname = "act-sts-header"
$rwpolname = "pol-sts-force"

#DHNAME key
$dhname = "dhkey2048.key"

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
    -Headers @{"Content-Type"="application/vnd.com.citrix.netscaler.login+json"} -Method POST|Out-Null
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
    -Headers @{"Content-Type"="application/vnd.com.citrix.netscaler.sslcipher_binding+json"} -Method PUT|Out-Null
}

function get-ciphers ($Name) {
    #Get cipher groups already on netscaler
    $ciphers = Invoke-RestMethod -uri "$hostname/nitro/v1/config/sslcipher" -WebSession $NSSession `
    -Headers @{"Content-Type"="application/json"} -Method GET
    return $ciphers.sslcipher
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
    -Headers @{"Content-Type"="application/vnd.com.citrix.netscaler.sslcipher+json"} -Method POST|Out-Null
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

function CipherGroup-vpx ($Name) {
    #Ciphers from https://www.citrix.com/blogs/2015/05/22/scoring-an-a-at-ssllabs-com-with-citrix-netscaler-the-sequel/
    #for VPXs had to remove TLS1.2-ECDHE-RSA-AES-128-SHA256
    $body = @{
        "sslcipher"=@{
            "ciphergroupname"="$Name";
            }
        }
    $body = ConvertTo-JSON $body
    Invoke-RestMethod -uri "$hostname/nitro/v1/config/sslcipher?action=add" -body $body -WebSession $NSSession `
    -Headers @{"Content-Type"="application/vnd.com.citrix.netscaler.sslcipher+json"} -Method POST|Out-Null
    #feel free to edit these
    Cipher $Name TLS1-ECDHE-RSA-AES256-SHA
    Cipher $Name TLS1-ECDHE-RSA-AES128-SHA
    Cipher $Name TLS1-DHE-RSA-AES-256-CBC-SHA
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
    -Headers @{"Content-Type"="application/vnd.com.citrix.netscaler.logout+json"} -Method POST|Out-Null
}

function set-cipher ($Name, $cipher){

    
    #unbinds all cipher groups
    $foundflag = 0 #flag if cipher already found
    $cgs = Invoke-RestMethod -uri "$hostname/nitro/v1/config/sslvserver_sslciphersuite_binding/$Name" -WebSession $NSSession `
    -Headers @{"Content-Type"="application/json"} -Method GET

    $cgs = $cgs.sslvserver_sslciphersuite_binding

    foreach ($cg in $cgs)
    {
        
        if ($cg.ciphername -notlike $cipher)
        {
        write-host "Unbinding" $cg.ciphername -ForegroundColor yellow

        Invoke-RestMethod -uri ("$hostname/nitro/v1/config/sslvserver_sslciphersuite_binding/$Name" + "?args=cipherName:" + $cg.ciphername ) -WebSession $NSSession `
        -Headers @{"Content-Type"="application/vnd.com.citrix.netscaler.sslvserver_sslciphersuite_binding+json"} -Method DELETE|Out-Null
        }
        else
        {
        write-host $cipher "already present.." -ForegroundColor Green
        $foundflag = 1
        }

    }


    if ($foundflag -eq 0)
        {
        #binds new cipher group created if not already present
        write-host "Binding $cipher" -ForegroundColor Yellow
        $body = ConvertTo-JSON @{
            "sslvserver_sslciphersuite_binding"=@{
                "vservername"="$Name";
                "ciphername"="$Cipher";
                }
            }
        Invoke-RestMethod -uri "$hostname/nitro/v1/config/sslvserver_sslciphersuite_binding/$Name" -body $body -WebSession $NSSession `
        -Headers @{"Content-Type"="application/vnd.com.citrix.netscaler.sslvserver_sslciphersuite_binding+json"} -Method PUT|Out-Null
        }
    
    #disables sslv2 and sslv3
    $body = ConvertTo-JSON @{
        "sslvserver"=@{
            "vservername"="$Name";
            "ssl3"="DISABLED";
            "ssl2"="DISABLED";
            "dh"="ENABLED";
            "dhfile"= $dhname;
            }
        }
    Invoke-RestMethod -uri "$hostname/nitro/v1/config/sslvserver/$Name" -body $body -WebSession $NSSession `
    -Headers @{"Content-Type"="application/vnd.com.citrix.netscaler.sslvserver+json"} -Method PUT|Out-Null

}

function set-nsip {
    #Adjusts SSL setting for IPV4 and IPV6 on 443
    $services = Invoke-RestMethod -uri "$hostname/nitro/v1/config/sslservice" -WebSession $NSSession `
    -Headers @{"Content-Type"="application/json"} -Method GET
    $services = $services.sslservice

    #only want nshttps services
    $nsips = $services|where{($_.servicename -like "nshttps-*") -or ($_.servicename -like "nskrpcs-*") -or ($_.servicename -like "nsrpcs-*") }
        foreach ($nsip in $nsips)
        {
        $name = $nsip.servicename
        write-host $name

        #disables sslv2 and sslv3
        $body = ConvertTo-JSON @{
            "sslservice"=@{
                "servicename"="$Name";
                "ssl3"="DISABLED";
                "ssl2"="DISABLED";
                "dh"="ENABLED";
                "dhfile"= $dhname;
                }
            }
        Invoke-RestMethod -uri "$hostname/nitro/v1/config/sslservice/$Name" -body $body -WebSession $NSSession `
        -Headers @{"Content-Type"="application/vnd.com.citrix.netscaler.sslservice+json"} -Method PUT|Out-Null
        }
}

function SaveConfig {
    #Saves NS config
    $body = ConvertTo-JSON @{
        "nsconfig"=@{
            }
        }
    Invoke-RestMethod -uri "$hostname/nitro/v1/config/nsconfig?action=save" -body $body -WebSession $NSSession `
    -Headers @{"Content-Type"="application/vnd.com.citrix.netscaler.nsconfig+json"} -Method POST|Out-Null
}

function get-rewritepol {
    #gets rewrite policies
    $pols = Invoke-RestMethod -uri "$hostname/nitro/v1/config/rewritepolicy" -WebSession $NSSession `
    -Headers @{"Content-Type"="application/json"} -Method GET
    return $pols.rewritepolicy
}

function EnableFeature ($feature) {
#enables NS feature
    $body = @{
        "nsfeature"=@{
            "feature"=$feature;
            }
        }
    $body = ConvertTo-JSON $body
    Invoke-RestMethod -uri "$hostname/nitro/v1/config/nsfeature?action=enable" -body $body -WebSession $NSSession `
    -Headers @{"Content-Type"="application/vnd.com.citrix.netscaler.nsfeature+json"} -Method POST|Out-Null
}

Function SetupSTS ($rwactname, $rwpolname) {

    # Strict Transport Security Policy creation


        EnableFeature Rewrite

        $body = ConvertTo-JSON @{
            "rewriteaction"=@{
                "name"=$rwactname;
                "type"="insert_http_header";
                "target"="Strict-Transport-Security";
                "stringbuilderexpr"='"max-age=157680000"';
                }
            }
        Invoke-RestMethod -uri "$hostname/nitro/v1/config/rewriteaction?action=add" -body $body -WebSession $NSSession `
        -Headers @{"Content-Type"="application/vnd.com.citrix.netscaler.rewriteaction+json"} -Method POST|Out-Null

        $body = ConvertTo-JSON @{
            "rewritepolicy"=@{
                "name"=$rwpolname;
                "action"=$rwactname;
                "rule"='true';
                }
            }
        Invoke-RestMethod -uri "$hostname/nitro/v1/config/rewritepolicy?action=add" -body $body -WebSession $NSSession `
        -Headers @{"Content-Type"="application/vnd.com.citrix.netscaler.rewritepolicy+json"} -Method POST|Out-Null
        
    
}

Function set-lbpols ($vip, $rwpolname){
#binds LB policy
    $name = $vip.name

            $body = ConvertTo-JSON @{
                "lbvserver_rewritepolicy_binding"=@{
                    "name"=$Name;
                    "policyname"=$rwpolname;
                    "priority"=100;
                    "bindpoint" = "RESPONSE";
                    }
                }
            Invoke-RestMethod -uri "$hostname/nitro/v1/config/lbvserver_rewritepolicy_binding/$Name" -body $body -WebSession $NSSession `
            -Headers @{"Content-Type"="application/vnd.com.citrix.netscaler.lbvserver_rewritepolicy_binding+json"} -Method POST|Out-Null
            

}

Function set-cspols ($vip, $rwpolname){
#binds CS policy
    $name = $vip.name

           $body = ConvertTo-JSON @{
                "csvserver_rewritepolicy_binding"=@{
                    "name"=$Name;
                    "policyname"=$rwpolname;
                    "priority"=100;
                    "bindpoint" = "RESPONSE";
                    }
                }
            Invoke-RestMethod -uri "$hostname/nitro/v1/config/csvserver_rewritepolicy_binding/$Name" -body $body -WebSession $NSSession `
            -Headers @{"Content-Type"="application/vnd.com.citrix.netscaler.csvserver_rewritepolicy_binding+json"} -Method PUT|Out-Null
            

}

Function set-vpnpols ($vip, $rwpolname){
#binds NG policy
    $name = $vip.name

        $body = ConvertTo-JSON @{
                "vpnvserver_rewritepolicy_binding"=@{
                    "name"=$Name;
                    "policy"=$rwpolname;
                    "priority"=100;
                    "gotopriorityexpression" = "END";
                    "bindpoint" = "RESPONSE";
                    }
                }
            Invoke-RestMethod -uri "$hostname/nitro/v1/config/vpnvserver_rewritepolicy_binding/$Name" -body $body -WebSession $NSSession `
            -Headers @{"Content-Type"="application/vnd.com.citrix.netscaler.vpnvserver_rewritepolicy_binding+json"} -Method POST|Out-Null
            

}

function checkvpx {
    #Checks if NS is a VPX or not
    $info = Invoke-RestMethod -uri "$hostname/nitro/v1/config/nshardware" -WebSession $NSSession `
    -Headers @{"Content-Type"="application/json"} -Method GET
    $info = $info.nshardware
        if ($info.hwdescription -like "NetScaler Virtual Appliance")
        {
            write-host "VPX FOUND..." -ForegroundColor Gray
            $found = $true
            }
            else
            {
        $found = $false
        }
Return $found
}

function new-dhkey ($name) {

    #Creates new DH Key
    $body = @{
                    
        "ssldhparam"= @{
            "dhfile"= $name;
            "bits"="2048";
            "gen"="2";
            }
        }
try {        
    $body = ConvertTo-JSON $body
    Invoke-RestMethod -uri "$hostname/nitro/v1/config/ssldhparam?action=create" -body $body -WebSession $NSSession `
    -Headers @{"Content-Type"="application/json"} -Method POST -TimeoutSec 240
    }
Catch
{
    $ErrorMessage = $_.Exception
    $FailedItem = $_.Exception.ItemName
}
    if ($ErrorMessage.Response.StatusCode -like "Conflict")
    {
    write-host $name "already present" -ForegroundColor Green
    }


}



###Script starts here
CLS
#Logs into netscaler
write-host "Logging in..."
Login

write-host "Creating" $dhname  -ForegroundColor DarkMagenta
write-host "This can take a couple of minutes..." -ForegroundColor yellow
#Checks for and creates DH key
new-dhkey $dhname

write-host "Checking for cipher group..." -ForegroundColor DarkMagenta
#Checks for cipher group we will be creating    
    if (((get-ciphers).ciphergroupname) -notcontains $ciphergroupname)
    {
        write-host "Creating " $ciphergroupname -ForegroundColor Gray
        if (checkvpx)
        {
            write-host "Creating cipher group for VPX..."
            CipherGroup-vpx $ciphergroupname
        }
         else
        {
            write-host "Creating cipher group for NON-VPX..."
            ciphergroup $ciphergroupname
        }
    }
    else
    {
    write-host $ciphergroupname "already present" -ForegroundColor Green
    }

write-host "Checking for rewrite policy..." -ForegroundColor DarkMagenta
#Checks for rewrite policy
    if (((get-rewritepol).name) -notcontains $rwpolname)
    {
        write-host "Creating " $rwpolname -ForegroundColor Gray
        SetupSTS $rwactname $rwpolname
    }
    else
    {
    write-host $rwpolname "already present" -ForegroundColor Green
    }

write-host "Adjusting SSL managment IPs..." -ForegroundColor DarkMagenta
#adjusts all managment IPs.  Does not adjust ciphers
set-nsip

write-host "Checking LB VIPs..." -ForegroundColor DarkMagenta
#Gets all LB servers that are SSL and makes changes
$lbservers = (get-vservers)
$ssls = $lbservers|where{$_.servicetype -like "SSL"}
foreach ($ssl in $ssls){
    write-host $ssl.name
    (set-cipher $ssl.name $ciphergroupname)
    (set-lbpols $ssl $rwpolname).message
}

write-host "Checking NG VIPs..." -ForegroundColor DarkMagenta
#Gets all Netscaler Gateways and makes changes
$vpnservers = get-vpnservers
foreach ($ssl in $vpnservers){
    write-host $ssl.name
    (set-cipher $ssl.name $ciphergroupname)
    (set-vpnpols $ssl $rwpolname).message
}

write-host "Checking CS VIPs..." -ForegroundColor DarkMagenta
#Gets all Content Switches and makes changes
$csservers = get-csservers
#Filters for only SSL
$csssls = $csservers|where{$_.servicetype -like "SSL"}
foreach ($sslcs in $csssls){
    write-host $sslcs.name
   (set-cipher $sslcs.name $ciphergroupname)
   (set-cspols $sslcs $rwpolname).message
}


write-host "Saving NS config.." -ForegroundColor DarkMagenta
#Save NS Config
SaveConfig

write-host "Logging out..." -ForegroundColor DarkMagenta
#Logout
Logout

