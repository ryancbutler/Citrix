<#
.SYNOPSIS
   Grabs Netscaler license expiration information via REST
.DESCRIPTION
   Grabs Netscaler license expiration information via REST. 
   Version: 0.9
   By: Ryan Butler 8-12-16 
    10-4-16: Now uses Netscaler time VS local system time
   Twitter: ryan_c_butler
   Website: Techdrabble.com
   Requires: Powershell v3 or greater
.PARAMETER nsip
   DNS Name or IP of the Netscaler that needs to be configured. (MANDATORY)
.PARAMETER adminaccount
   Netscaler admin account (Default: nsroot)
.PARAMETER adminpassword
   Password for the Netscaler admin account (Default: nsroot)
.PARAMETER https
   Use HTTPS for communication
.EXAMPLE
   ./get-nslicexp -nsip 10.1.1.2
.EXAMPLE
   ./get-nslicexp -nsip 10.1.1.2 | ft -AutoSize
.EXAMPLE
   ./get-nslicexp -nsip 10.1.1.2 -https
.EXAMPLE
   ./get-nslicexp -nsip 10.1.1.2 -adminaccount nsadmin -adminpassword "mysupersecretpassword"
   #>
Param
(
    [Parameter(Mandatory=$true)]$nsip,
    [String]$adminaccount="nsroot",
    [String]$adminpassword="nsroot",
    [switch]$https
)



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


function Login-ns {
 # Login to NetScaler and save session to global variable
    $body = ConvertTo-JSON @{
        "login"=@{
            "username"="$username";
            "password"="$password"
            }
        }
    try {
    Invoke-RestMethod -uri "$hostname/nitro/v1/config/login" -body $body -SessionVariable NSSession `
    -Headers @{"Content-Type"="application/vnd.com.citrix.netscaler.login+json"} -Method POST|Out-Null
    $Script:NSSession = $local:NSSession
    }
    Catch
    {
    throw $_
    }
}

function Logout-ns {
#logs out of Netscaler
    $body = ConvertTo-JSON @{
        "logout"=@{
            }
        }
    Invoke-RestMethod -uri "$hostname/nitro/v1/config/logout" -body $body -WebSession $NSSession `
    -Headers @{"Content-Type"="application/vnd.com.citrix.netscaler.logout+json"} -Method POST|Out-Null
}


function get-nslicense ($filename) {
    #Grabs license file
    $urlstring = "$hostname" + "/nitro/v1/config/systemfile/" + $filename+ "?args=filelocation:%2Fnsconfig%2Flicense"
try {
    $info = Invoke-RestMethod -uri $urlstring -WebSession $NSSession `
    -Headers @{"Content-Type"="application/json"} -Method GET
    $msg = $info.message
}
Catch
{
    $ErrorMessage = $_.Exception.Response
    $FailedItem = $_.Exception.ItemName
}

#Converts returned value from BASE64 to UTF8
$info = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($info.systemfile.filecontent))

#Grabs needed line that has licensing information
$lines = $info.Split("`n")|where{$_ -like "*INCREMENT*"}

#Parses needed date values from string
$licdates = @()
foreach ($line in $lines)
{
$licdate = $line.Split()
write-host $licdate

    if ($licdate[4] -like "permanent")
    {
    $expire = "PERMANENT"
    }
    else
    {
    $expire = [datetime]$licdate[4]
    }

#adds date to object
$temp = New-Object PSObject -Property @{
                expdate = $expire
                feature = $licdate[1]
                }
$licdates += $temp
}

Return $licdates
}

function get-nslicenses {
#Gets available license files
    
    $urlstring = "$hostname" + "/nitro/v1/config/systemfile?args=filelocation:%2Fnsconfig%2Flicense"
try {
    $info = Invoke-RestMethod -uri $urlstring -WebSession $NSSession `
    -Headers @{"Content-Type"="application/json"} -Method GET
    $msg = $info.message
}
Catch
{
    $ErrorMessage = $_.Exception.Response
    $FailedItem = $_.Exception.ItemName
}

$info = $info.systemfile|where{$_.filename -like "*.lic"}

Return $info
}

function check-nslicense () {
#Compares dates and places results into array
$currentnstime = get-nstime
write-host "Current NS Time:" $currentnstime
$licenses = get-nslicenses
$results = @()

    foreach($license in $licenses)
    {
    write-host $license.filename -ForegroundColor Green
    $dates = get-nslicense($license.filename)
        foreach ($date in $dates)
        {
            if ($date.expdate -like "PERMANENT")
            {
                $expires = "PERMANENT"
                $span = "9999"
            }
            else
            {
                $expires = ($date.expdate).ToShortDateString()
                $span = (New-TimeSpan -Start $currentnstime -end ($date.expdate)).days
            }
        
        $temp = New-Object PSObject -Property @{
                Expires = $expires
                Feature = $date.feature
                DaysLeft = $span
                LicenseFile = $license.filename
                NSIP = $nsip
                }
        $results += $temp    
        }

    }
return $results
}

function get-nstime {
#Gets currenttime from netscaler
    
    $urlstring = "$hostname" + "/nitro/v1/config/nsconfig"
try {
    $info = Invoke-RestMethod -uri $urlstring -WebSession $NSSession `
    -Headers @{"Content-Type"="application/json"} -Method GET
    $currentdatestr = $info.nsconfig.currentsytemtime
}
Catch
{
    $ErrorMessage = $_.Exception.Response
    $FailedItem = $_.Exception.ItemName
}
#converts string into datetime format
#Fix for dates with single day integer
$currentdatestr = $currentdatestr -replace "  "," 0"
$nsdate = [DateTime]::ParseExact($currentdatestr,"ddd MMM dd HH:mm:ss yyyy",$null)
return $nsdate
}

#Call functions here
login-ns
return check-nslicense
logout-ns