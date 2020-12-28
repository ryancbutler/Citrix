<#PSScriptInfo

.VERSION 1.3

.GUID 39040cec-77cd-48c0-8f25-4f8a19568740

.AUTHOR @ryan_c_butler

.COMPANYNAME Techdrabble.com

.COPYRIGHT 2016

.TAGS Netscaler REST License

.LICENSEURI https://github.com/ryancbutler/Citrix/blob/master/License.txt

.PROJECTURI https://github.com/ryancbutler/Citrix

.ICONURI 

.EXTERNALMODULEDEPENDENCIES 

.REQUIREDSCRIPTS 

.EXTERNALSCRIPTDEPENDENCIES 

.RELEASENOTES
10-4-16: Now uses Netscaler time VS local system time
12-14-16: Fix for double digit days
12-28-16: Better error handling when grabbing license files and NS version check
08-27-17: Formatting for PS Gallery
10-30-20: Date conversion fix and better output

#>

<#
.SYNOPSIS
   Grabs Netscaler license expiration information via REST
.DESCRIPTION
   Grabs Netscaler license expiration information via REST.
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
[cmdletbinding()]
param
(
	[Parameter(Mandatory = $true)] $nsip,
	[string]$adminaccount = "nsroot",
	[string]$adminpassword = "nsroot",
	[switch]$https
)



#Netscaler NSIP login information
if ($https) {
	[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls
	[System.Net.ServicePointManager]::ServerCertificateValidationCallback = { $true }
	write-verbose "Connecting HTTPS"
	$hostname = "https://" + $nsip
}
else {
	write-verbose "Connecting HTTP"
	$hostname = "http://" + $nsip
}


$username = $adminaccount
$password = $adminpassword



##Functions
###############################
#Probably not much you have to edit below this
###############################


function login-ns {
	# Login to NetScaler and save session to global variable
	$body = ConvertTo-Json @{
		"login" = @{
			"username" = "$username";
			"password" = "$password"
		}
	# un-escape because this causes issues with special characters	
	}  | ForEach-Object { [System.Text.RegularExpressions.Regex]::Unescape($_) }
	try {
		Invoke-RestMethod -Uri "$hostname/nitro/v1/config/login" -Body $body -SessionVariable NSSession `
			-Headers @{ "Content-Type" = "application/vnd.com.citrix.netscaler.login+json" } -Method POST | Out-Null
		$Script:NSSession = $local:NSSession
	}
	catch {
		throw $_
	}
}

function Logout-ns {
	#logs out of Netscaler
	$body = ConvertTo-Json @{
		"logout" = @{
		}
	}
	Invoke-RestMethod -Uri "$hostname/nitro/v1/config/logout" -Body $body -WebSession $NSSession `
		-Headers @{ "Content-Type" = "application/vnd.com.citrix.netscaler.logout+json" } -Method POST | Out-Null
}


function get-nslicense ($filename) {
	#Grabs license file
	$urlstring = "$hostname" + "/nitro/v1/config/systemfile/" + $filename + "?args=filelocation:%2Fnsconfig%2Flicense"
	try {
		$info = Invoke-RestMethod -Uri $urlstring -WebSession $NSSession `
			-Headers @{ "Content-Type" = "application/json" } -Method GET
		$msg = $info.message
	}
	catch {
		throw "Error reading license(s): " + ($_.ErrorDetails.message | ConvertFrom-Json).message

	}

	#Converts returned value from BASE64 to UTF8
	$info = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($info.systemfile.filecontent))

	#Grabs needed line that has licensing information
	$lines = $info.Split("`n") | Where-Object { $_ -like "*INCREMENT*" }

	#Parses needed date values from string
	$licdates = @()
	foreach ($line in $lines) {
		$licdate = $line.Split()


		if ($licdate[4] -like "permanent") {
			$expire = "PERMANENT"
		}
		else {
			$expire = [datetime]$licdate[4]
		}

		#adds date to object
		$temp = New-Object PSObject -Property @{
			expdate = $expire
			feature = $licdate[1]
		}
		$licdates += $temp
	}

	return $licdates
}

function get-nslicenses {
	#Gets available license files

	$urlstring = "$hostname" + "/nitro/v1/config/systemfile?args=filelocation:%2Fnsconfig%2Flicense"
	try {
		$info = Invoke-RestMethod -Uri $urlstring -WebSession $NSSession `
			-Headers @{ "Content-Type" = "application/json" } -Method GET
		$msg = $info.message
	}
	catch {
		throw "Error locating license(s): " + ($_.ErrorDetails.message | ConvertFrom-Json).message

	}

	$info = $info.systemfile | Where-Object { $_.filename -like "*.lic" }

	return $info
}

function check-nslicense () {
	#Compares dates and places results into array
	$currentnstime = get-nstime
	Write-verbose "Current NS Time: $currentnstime" 
	$licenses = get-nslicenses
	$results = @()

	foreach ($license in $licenses) {
		Write-verbose $license.filename
		$dates = get-nslicense ($license.filename)
		foreach ($date in $dates) {
			if ($date.expdate -like "PERMANENT") {
				$expires = "PERMANENT"
				$span = "9999"
			}
			else {
				$expires = ($date.expdate).ToShortDateString()
				$span = (New-TimeSpan -Start $currentnstime -End ($date.expdate)).days
			}

			$temp = New-Object PSObject -Property @{
				Expires     = $expires
				feature     = $date.feature
				DaysLeft    = $span
				LicenseFile = $license.filename
				NSIP        = $nsip
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
		$info = Invoke-RestMethod -Uri $urlstring -WebSession $NSSession `
			-Headers @{ "Content-Type" = "application/json" } -Method GET
		$currentdatestr = $info.nsconfig.currentsytemtime
	}
	catch {
		$ErrorMessage = $_.Exception.Response
		$FailedItem = $_.Exception.ItemName
	}
	#converts string into datetime format
	#Fix for dates with single day integer
	$currentdatestr = $currentdatestr -replace "  ", " 0"
	$nsdate = [datetime]::ParseExact($currentdatestr, "ddd MMM dd HH:mm:ss yyyy", [System.Globalization.CultureInfo]::InvariantCulture)
	return $nsdate
}

function check-nsversion {
	#Checks for supported NS version
	$info = Invoke-RestMethod -Uri "$hostname/nitro/v1/config/nsversion" -WebSession $NSSession `
		-Headers @{ "Content-Type" = "application/json" } -Method GET
	$version = $info.nsversion.version
	$version = $version.Substring(12, 4)

	if ($version -lt 10.5) {
		throw "Version of Netsaler firmware must be greater or equal to 10.5"
	}

}

#Call functions here
login-ns
check-nsversion
return check-nslicense
Logout-ns
