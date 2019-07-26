<#PSScriptInfo

.VERSION 1.3

.GUID 2a8be02b-621b-46be-9f20-c373a3882927

.AUTHOR @ryan_c_butler

.COMPANYNAME Techdrabble.com

.COPYRIGHT 2016

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

#>



<#
.SYNOPSIS
   A PowerShell script for hardening Netscaler SSL IPs based off of SSL LABS
.DESCRIPTION
   A PowerShell script that enables TLS 1.2, disables SSLv2 and SSLv3, creates and binds Diffie-Hellman (DH) key, creates and binds "Strict Transport Security policy" and removes all other ciphers and binds cipher group mentioned in https://www.citrix.com/blogs/2015/05/22/scoring-an-a-at-ssllabs-com-with-citrix-netscaler-the-sequel/
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
param
(
	[Parameter(Mandatory = $true)] $nsip,
	[string]$adminaccount = "nsroot",
	[string]$adminpassword = "nsroot",
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
if ($https)
{
	[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls
	[System.Net.ServicePointManager]::ServerCertificateValidationCallback = { $true }
	Write-Host "Connecting HTTPS" -ForegroundColor Yellow
	$hostname = "https://" + $nsip
}
else
{
	Write-Host "Connecting HTTP" -ForegroundColor Yellow
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
	$body = ConvertTo-Json @{
		"login" = @{
			"username" = "$username";
			"password" = "$password"
		}
	}
	try {
		Invoke-RestMethod -Uri "$hostname/nitro/v1/config/login" -Body $body -SessionVariable NSSession `
 			-Headers @{ "Content-Type" = "application/vnd.com.citrix.netscaler.login+json" } -Method POST | Out-Null
		$Script:NSSession = $local:NSSession
	}
	catch
	{
		throw $_
	}
}

function Cipher ($Name,$Cipher) {

	# Support function called by CipherGroup
	$body = @{
		"sslcipher_binding" = [ordered]@{
			"ciphergroupname" = "$Name";
			"ciphername" = "$Cipher";
		}
	}
	$body = ConvertTo-Json $body
	try {
		Invoke-RestMethod -Uri "$hostname/nitro/v1/config/sslcipher_binding/$Name" -Body $body -WebSession $NSSession `
 			-Headers @{ "Content-Type" = "application/vnd.com.citrix.netscaler.sslcipher_binding+json" } -Method PUT | Out-Null
	}
	catch
	{
		Write-Warning ($_.ErrorDetails | ConvertFrom-Json).message
	}
}

function get-ciphers ($Name) {
	#Get cipher groups already on netscaler
	try {
		$ciphers = Invoke-RestMethod -Uri "$hostname/nitro/v1/config/sslcipher" -WebSession $NSSession `
 			-Headers @{ "Content-Type" = "application/json" } -Method GET
	}
	catch
	{
		Write-Warning ($_.ErrorDetails | ConvertFrom-Json).message
	}

	return $ciphers.sslcipher
}

function CipherGroup ($Name) {
	$body = @{
		"sslcipher" = @{
			"ciphergroupname" = "$Name";
		}
	}
	$body = ConvertTo-Json $body
	try {
		Invoke-RestMethod -Uri "$hostname/nitro/v1/config/sslcipher?action=add" -Body $body -WebSession $NSSession `
 			-Headers @{ "Content-Type" = "application/vnd.com.citrix.netscaler.sslcipher+json" } -Method POST | Out-Null
	}
	catch
	{
		Write-Warning ($_.ErrorDetails | ConvertFrom-Json).message
	}
	#feel free to edit these
	Cipher $Name TLS1.2-ECDHE-RSA-AES256-GCM-SHA384
	Cipher $Name TLS1.2-ECDHE-RSA-AES128-GCM-SHA256
	Cipher $Name TLS1.2-ECDHE-RSA-AES-256-SHA384
	Cipher $Name TLS1.2-ECDHE-RSA-AES-128-SHA256
	Cipher $Name TLS1-ECDHE-RSA-AES256-SHA
	Cipher $Name TLS1-ECDHE-RSA-AES128-SHA
	Cipher $Name TLS1.2-DHE-RSA-AES256-GCM-SHA384
	Cipher $Name TLS1.2-DHE-RSA-AES128-GCM-SHA256
	Cipher $Name TLS1-DHE-RSA-AES-256-CBC-SHA
	Cipher $Name TLS1-DHE-RSA-AES-128-CBC-SHA
	Cipher $Name TLS1-AES-256-CBC-SHA
	Cipher $Name TLS1-AES-128-CBC-SHA
	Cipher $Name SSL3-DES-CBC3-SHA
}

function CipherGroup-vpx ($Name) {
	$body = @{
		"sslcipher" = @{
			"ciphergroupname" = "$Name";
		}
	}
	$body = ConvertTo-Json $body
	try {
		Invoke-RestMethod -Uri "$hostname/nitro/v1/config/sslcipher?action=add" -Body $body -WebSession $NSSession `
 			-Headers @{ "Content-Type" = "application/vnd.com.citrix.netscaler.sslcipher+json" } -Method POST | Out-Null
		#feel free to edit these
	}
	catch
	{
		Write-Warning ($_.ErrorDetails | ConvertFrom-Json).message
	}
	Cipher $Name TLS1.2-ECDHE-RSA-AES256-GCM-SHA384
	Cipher $Name TLS1.2-ECDHE-RSA-AES128-GCM-SHA256
	Cipher $Name TLS1.2-ECDHE-RSA-AES-256-SHA384
	Cipher $Name TLS1.2-ECDHE-RSA-AES-128-SHA256
	Cipher $Name TLS1-ECDHE-RSA-AES256-SHA
	Cipher $Name TLS1-ECDHE-RSA-AES128-SHA
	Cipher $Name TLS1.2-DHE-RSA-AES256-GCM-SHA384
	Cipher $Name TLS1.2-DHE-RSA-AES128-GCM-SHA256
	Cipher $Name TLS1-DHE-RSA-AES-256-CBC-SHA
	Cipher $Name TLS1-DHE-RSA-AES-128-CBC-SHA
	Cipher $Name TLS1-AES-256-CBC-SHA
	Cipher $Name TLS1-AES-128-CBC-SHA
	Cipher $Name SSL3-DES-CBC3-SHA
}

function get-vpnservers {
	#gets netscaler gateway VIPs
	try {
		$vips = Invoke-RestMethod -Uri "$hostname/nitro/v1/config/vpnvserver" -WebSession $NSSession `
 			-Headers @{ "Content-Type" = "application/json" } -Method GET
	}
	catch
	{
		Write-Warning ($_.ErrorDetails | ConvertFrom-Json).message
	}
	return $vips.vpnvserver
}

function get-vservers {
	#gets load balancers
	try {
		$vips = Invoke-RestMethod -Uri "$hostname/nitro/v1/config/lbvserver" -WebSession $NSSession `
 			-Headers @{ "Content-Type" = "application/json" } -Method GET
	}
	catch
	{
		Write-Warning ($_.ErrorDetails | ConvertFrom-Json).message
	}
	return $vips.lbvserver
}

function get-csservers {
	#gets content switches
	try {
		$vips = Invoke-RestMethod -Uri "$hostname/nitro/v1/config/csvserver" -WebSession $NSSession `
 			-Headers @{ "Content-Type" = "application/json" } -Method GET
	}
	catch
	{
		Write-Warning ($_.ErrorDetails | ConvertFrom-Json).message
	}
	return $vips.csvserver
}

function Logout {
	#logs out
	$body = ConvertTo-Json @{
		"logout" = @{
		}
	}
	try {
		Invoke-RestMethod -Uri "$hostname/nitro/v1/config/logout" -Body $body -WebSession $NSSession `
 			-Headers @{ "Content-Type" = "application/vnd.com.citrix.netscaler.logout+json" } -Method POST | Out-Null
	}
	catch
	{
		Write-Warning ($_.ErrorDetails | ConvertFrom-Json).message
	}
}

function set-cipher ($Name,$cipher) {


	#unbinds all cipher groups
	$foundflag = 0 #flag if cipher already found
	$cgs = Invoke-RestMethod -Uri "$hostname/nitro/v1/config/sslvserver_sslciphersuite_binding/$Name" -WebSession $NSSession `
 		-Headers @{ "Content-Type" = "application/json" } -Method GET

	$cgs = $cgs.sslvserver_sslciphersuite_binding

	foreach ($cg in $cgs)
	{

		if ($cg.ciphername -notlike $cipher)
		{
			Write-Host "Unbinding" $cg.ciphername -ForegroundColor yellow
			try {
				Invoke-RestMethod -Uri ("$hostname/nitro/v1/config/sslvserver_sslciphersuite_binding/$Name" + "?args=cipherName:" + $cg.ciphername) -WebSession $NSSession `
 					-Headers @{ "Content-Type" = "application/vnd.com.citrix.netscaler.sslvserver_sslciphersuite_binding+json" } -Method DELETE | Out-Null
			}
			catch
			{
				Write-Warning ($_.ErrorDetails | ConvertFrom-Json).message
			}
		}
		else
		{
			Write-Host $cipher "already present.." -ForegroundColor Green
			$foundflag = 1
		}

	}

	#Make sure SSL profile not in use
	if ($useprofile -eq $false)
	{
		if ($foundflag -eq 0)
		{
			#binds new cipher group created if not already present
			Write-Host "Binding $cipher" -ForegroundColor Yellow
			$body = ConvertTo-Json @{
				"sslvserver_sslciphersuite_binding" = @{
					"vservername" = "$Name";
					"ciphername" = "$Cipher";
				}
			}
			try {
				Invoke-RestMethod -Uri "$hostname/nitro/v1/config/sslvserver_sslciphersuite_binding/$Name" -Body $body -WebSession $NSSession `
 					-Headers @{ "Content-Type" = "application/vnd.com.citrix.netscaler.sslvserver_sslciphersuite_binding+json" } -Method PUT | Out-Null
			}
			catch
			{
				Write-Warning ($_.ErrorDetails | ConvertFrom-Json).message
			}
		}

		#disables sslv2 and sslv3
		$body = ConvertTo-Json @{
			"sslvserver" = @{
				"vservername" = "$Name";
				"tls12" = "ENABLED";
				"ssl3" = "DISABLED";
				"ssl2" = "DISABLED";
				"dh" = "ENABLED";
				"dhfile" = $dhname;
			}
		}
		try {
			Invoke-RestMethod -Uri "$hostname/nitro/v1/config/sslvserver/$Name" -Body $body -WebSession $NSSession `
 				-Headers @{ "Content-Type" = "application/vnd.com.citrix.netscaler.sslvserver+json" } -Method PUT | Out-Null
		}
		catch
		{
			Write-Warning ($_.ErrorDetails | ConvertFrom-Json).message
		}
	}
}

function set-nscipher ($Name,$cipher) {


	#unbinds all cipher groups
	$foundflag = 0 #flag if cipher already found
	$cgs = Invoke-RestMethod -Uri "$hostname/nitro/v1/config/sslservice_sslciphersuite_binding/$Name" -WebSession $NSSession `
 		-Headers @{ "Content-Type" = "application/json" } -Method GET

	$cgs = $cgs.sslservice_sslciphersuite_binding

	foreach ($cg in $cgs)
	{

		if ($cg.ciphername -notlike $cipher)
		{
			Write-Host "Unbinding" $cg.ciphername -ForegroundColor yellow
			try {
				Invoke-RestMethod -Uri ("$hostname/nitro/v1/config/sslservice_sslciphersuite_binding/$Name" + "?args=cipherName:" + $cg.ciphername) -WebSession $NSSession `
 					-Headers @{ "Content-Type" = "application/vnd.com.citrix.netscaler.sslservice_sslciphersuite_binding+json" } -Method DELETE | Out-Null
			}
			catch
			{
				Write-Warning ($_.ErrorDetails | ConvertFrom-Json).message
			}
		}
		else
		{
			Write-Host $cipher "already present.." -ForegroundColor Green
			$foundflag = 1
		}

	}


	if ($foundflag -eq 0)
	{
		#binds new cipher group created if not already present
		Write-Host "Binding $cipher" -ForegroundColor Yellow
		$body = ConvertTo-Json @{
			"sslservice_sslciphersuite_binding" = @{
				"servicename" = "$Name";
				"ciphername" = "$Cipher";
			}
		}
		try {
			Invoke-RestMethod -Uri "$hostname/nitro/v1/config/sslservice_sslciphersuite_binding/$Name" -Body $body -WebSession $NSSession `
 				-Headers @{ "Content-Type" = "application/vnd.com.citrix.netscaler.sslservice_sslciphersuite_binding+json" } -Method PUT | Out-Null
		}
		catch
		{
			Write-Warning ($_.ErrorDetails | ConvertFrom-Json).message
		}
	}


}

function set-nsip {
	#Adjusts SSL setting for IPV4 and IPV6 on 443
	$services = Invoke-RestMethod -Uri "$hostname/nitro/v1/config/sslservice" -WebSession $NSSession `
 		-Headers @{ "Content-Type" = "application/json" } -Method GET
	$services = $services.sslservice

	#only want nshttps services
	$nsips = $services | Where-Object { ($_.servicename -like "nshttps-*") -or ($_.servicename -like "nskrpcs-*") -or ($_.servicename -like "nsrpcs-*") }
	foreach ($nsip in $nsips)
	{
		$name = $nsip.servicename
		Write-Host $name
		if ($useprofile)
		{
			#Assigning SSL Profile and disabling SSLV2
			$body = ConvertTo-Json @{
				"sslservice" = @{
					"servicename" = "$Name";
					"sslprofile" = $sslprofile;
					"ssl2" = "DISABLED";
				} }
			try {
				Invoke-RestMethod -Uri "$hostname/nitro/v1/config/sslservice/$Name" -Body $body -WebSession $NSSession `
 					-Headers @{ "Content-Type" = "application/json" } -Method PUT | Out-Null
			}
			catch
			{
				Write-Warning ($_.ErrorDetails | ConvertFrom-Json).message
			}


		}
		else
		{
			#No SSL Profile
			$body = ConvertTo-Json @{
				"sslservice" = @{
					"servicename" = "$Name";
					"tls12" = "ENABLED";
					"ssl3" = "DISABLED";
					"ssl2" = "DISABLED";
					"dh" = "ENABLED";
					"dhfile" = $dhname;
				}
			}
			try {
				Invoke-RestMethod -Uri "$hostname/nitro/v1/config/sslservice/$Name" -Body $body -WebSession $NSSession `
 					-Headers @{ "Content-Type" = "application/vnd.com.citrix.netscaler.sslservice+json" } -Method PUT | Out-Null
			}
			catch
			{
				Write-Warning ($_.ErrorDetails | ConvertFrom-Json).message
			}
			set-nscipher $name $ciphergroupname
		}

	}
}

function set-sslprofilebind ($name,$sslprofile) {
	#Sets SSL Profile and disables SSLv2
	$body = ConvertTo-Json @{
		"sslvserver" = @{
			"vservername" = "$Name";
			"sslprofile" = $sslprofile;
			"ssl2" = "DISABLED";
		} }

	try {
		Invoke-RestMethod -Uri "$hostname/nitro/v1/config/sslvserver/$Name" -Body $body -WebSession $NSSession `
 			-Headers @{ "Content-Type" = "application/json" } -Method PUT | Out-Null
	}
	catch
	{
		Write-Warning ($_.ErrorDetails | ConvertFrom-Json).message
	}
}

function SaveConfig {
	#Saves NS config
	$body = ConvertTo-Json @{
		"nsconfig" = @{
		}
	}
	try {
		Invoke-RestMethod -Uri "$hostname/nitro/v1/config/nsconfig?action=save" -Body $body -WebSession $NSSession `
 			-Headers @{ "Content-Type" = "application/vnd.com.citrix.netscaler.nsconfig+json" } -Method POST | Out-Null
	}
	catch
	{
		Write-Warning ($_.ErrorDetails | ConvertFrom-Json).message
	}
}

function get-rewritepol {
	#gets rewrite policies
	try {
		$pols = Invoke-RestMethod -Uri "$hostname/nitro/v1/config/rewritepolicy" -WebSession $NSSession `
 			-Headers @{ "Content-Type" = "application/json" } -Method GET
	}
	catch
	{
		Write-Warning ($_.ErrorDetails | ConvertFrom-Json).message
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
	$body = ConvertTo-Json $body
	try {
		Invoke-RestMethod -Uri "$hostname/nitro/v1/config/nsfeature?action=enable" -Body $body -WebSession $NSSession `
 			-Headers @{ "Content-Type" = "application/vnd.com.citrix.netscaler.nsfeature+json" } -Method POST | Out-Null
	}
	catch
	{
		Write-Warning ($_.ErrorDetails | ConvertFrom-Json).message
	}
}

function SetupSTS ($rwactname,$rwpolname) {

	# Strict Transport Security Policy creation


	EnableFeature Rewrite

	$body = ConvertTo-Json @{
		"rewriteaction" = @{
			"name" = $rwactname;
			"type" = "insert_http_header";
			"target" = "Strict-Transport-Security";
			"stringbuilderexpr" = '"max-age=157680000"';
		}
	}
	try {
		Invoke-RestMethod -Uri "$hostname/nitro/v1/config/rewriteaction?action=add" -Body $body -WebSession $NSSession `
 			-Headers @{ "Content-Type" = "application/vnd.com.citrix.netscaler.rewriteaction+json" } -Method POST | Out-Null
	}
	catch
	{
		Write-Warning ($_.ErrorDetails | ConvertFrom-Json).message
	}

	$body = ConvertTo-Json @{
		"rewritepolicy" = @{
			"name" = $rwpolname;
			"action" = $rwactname;
			"rule" = 'true';
		}
	}
	try {
		Invoke-RestMethod -Uri "$hostname/nitro/v1/config/rewritepolicy?action=add" -Body $body -WebSession $NSSession `
 			-Headers @{ "Content-Type" = "application/vnd.com.citrix.netscaler.rewritepolicy+json" } -Method POST | Out-Null
	}
	catch
	{
		Write-Warning ($_.ErrorDetails | ConvertFrom-Json).message
	}

}

function set-lbpols ($vip,$rwpolname,$rwpolpri) {
	#binds LB policy
	$name = $vip.Name

	$body = ConvertTo-Json @{
		"lbvserver_rewritepolicy_binding" = @{
			"name" = $Name;
			"policyname" = $rwpolname;
			"priority" = $rwpolpri;
			"bindpoint" = "RESPONSE";
		}
	}
	try {
		Invoke-RestMethod -Uri "$hostname/nitro/v1/config/lbvserver_rewritepolicy_binding/$Name" -Body $body -WebSession $NSSession `
 			-Headers @{ "Content-Type" = "application/vnd.com.citrix.netscaler.lbvserver_rewritepolicy_binding+json" } -Method POST | Out-Null
	}
	catch
	{
		Write-Warning ($_.ErrorDetails | ConvertFrom-Json).message
	}


}

function set-cspols ($vip,$rwpolname,$rwpolpri) {
	#binds CS policy
	$name = $vip.Name

	$body = ConvertTo-Json @{
		"csvserver_rewritepolicy_binding" = @{
			"name" = $Name;
			"policyname" = $rwpolname;
			"priority" = $rwpolpri;
			"bindpoint" = "RESPONSE";
		}
	}
	try {
		Invoke-RestMethod -Uri "$hostname/nitro/v1/config/csvserver_rewritepolicy_binding/$Name" -Body $body -WebSession $NSSession `
 			-Headers @{ "Content-Type" = "application/vnd.com.citrix.netscaler.csvserver_rewritepolicy_binding+json" } -Method PUT | Out-Null
	}
	catch
	{
		Write-Warning ($_.ErrorDetails | ConvertFrom-Json).message
	}


}

function set-vpnpols ($vip,$rwpolname,$rwpolpri) {
	#binds NG policy
	$name = $vip.Name

	$body = ConvertTo-Json @{
		"vpnvserver_rewritepolicy_binding" = @{
			"name" = $Name;
			"policy" = $rwpolname;
			"priority" = $rwpolpri;
			"gotopriorityexpression" = "END";
			"bindpoint" = "RESPONSE";
		}
	}
	try {
		Invoke-RestMethod -Uri "$hostname/nitro/v1/config/vpnvserver_rewritepolicy_binding/$Name" -Body $body -WebSession $NSSession `
 			-Headers @{ "Content-Type" = "application/vnd.com.citrix.netscaler.vpnvserver_rewritepolicy_binding+json" } -Method POST | Out-Null
	}
	catch
	{
		Write-Warning ($_.ErrorDetails | ConvertFrom-Json).message
	}


}

function checkvpx {
	#Checks if NS is a VPX or not
	$info = Invoke-RestMethod -Uri "$hostname/nitro/v1/config/nshardware" -WebSession $NSSession `
 		-Headers @{ "Content-Type" = "application/json" } -Method GET
	$info = $info.nshardware
	if ($info.hwdescription -like "NetScaler Virtual Appliance")
	{
		Write-Host "VPX FOUND..." -ForegroundColor Gray
		$found = $true
	}
	else
	{
		$found = $false
	}
	return $found
}

function new-dhkey ($name) {

	#Creates new DH Key
	$body = @{

		"ssldhparam" = @{
			"dhfile" = $name;
			"bits" = "2048";
			"gen" = "2";
		}
	}

	$body = ConvertTo-Json $body
	Invoke-RestMethod -Uri "$hostname/nitro/v1/config/ssldhparam?action=create" -Body $body -WebSession $NSSession `
 		-Headers @{ "Content-Type" = "application/json" } -Method POST -TimeoutSec 600


}

function checkfordhkey ($dhname) {
	#Checks if DHKEY is present
	$urlstring = "$hostname" + "/nitro/v1/config/systemfile/" + $dhname + "?args=filelocation:%2Fnsconfig%2Fssl"
	try {
		$info = Invoke-RestMethod -Uri $urlstring -WebSession $NSSession `
 			-Headers @{ "Content-Type" = "application/json" } -Method GET
		$msg = $info.message
	}
	catch
	{
		$ErrorMessage = $_.Exception.Response
		$FailedItem = $_.Exception.ItemName
	}
	if ($msg -like "Done")
	{
		Write-Host "DHKEY alredy present..." -ForegroundColor Green
		$found = $true
	}
	else
	{
		Write-Host "DHKEY NOT present..." -ForegroundColor Yellow
		$found = $false
	}
	return $found
}

function set-sslparams {
	#Allow secure renegotiation

	$body = ConvertTo-Json @{
		"sslparameter" = @{
			"denysslreneg" = "FRONTEND_CLIENT";
		}
	}
	Invoke-RestMethod -Uri "$hostname/nitro/v1/config/sslparameter/" -Body $body -WebSession $NSSession `
 		-Headers @{ "Content-Type" = "application/json" } -Method PUT | Out-Null


}

function enable-sslprof {
	#Enables default SSL profile https://docs.citrix.com/en-us/netscaler/11-1/ssl/ssl-profiles1/ssl-enabling-the-default-profile.html 

	$body = ConvertTo-Json @{
		"sslparameter" = @{
			"defaultprofile" = "ENABLED";
		}
	}
	Invoke-RestMethod -Uri "$hostname/nitro/v1/config/sslparameter/" -Body $body -WebSession $NSSession `
 		-Headers @{ "Content-Type" = "application/json" } -Method PUT | Out-Null
}

function check-nsversion {
	#Checks for supported NS version
	$info = Invoke-RestMethod -Uri "$hostname/nitro/v1/config/nsversion" -WebSession $NSSession `
 		-Headers @{ "Content-Type" = "application/json" } -Method GET
	$version = $info.nsversion.version
	[regex]$majorreg = "(?<=NS).*?(?=:)"
	[regex]$minorreg = "(?<=Build ).*?(?=.n)"
	[version]$version = ($majorreg.match($version)).value + "." + ($minorreg.match($version)).value

	return $version
}

function check-defaultprofile {
	#Checks for SSL default profile
	$info = Invoke-RestMethod -Uri "$hostname/nitro/v1/config/sslparameter" -WebSession $NSSession `
 		-Headers @{ "Content-Type" = "application/json" } -Method GET
	return $info.sslparameter.defaultprofile
}

function check-sslprofile ($sslprofile) {
	try {
		#Checks for SSL default profile
		$info = Invoke-RestMethod -Uri "$hostname/nitro/v1/config/sslprofile/$sslprofile" -WebSession $NSSession `
 			-Headers @{ "Content-Type" = "application/json" } -Method GET
	}
	catch
	{
		$ErrorMessage = $_.Exception.Response
		$FailedItem = $_.Exception.ItemName
	}

	if ($info.sslprofile)
	{
		Write-Host "Found SSL PROFILE $sslprofile" -ForegroundColor Green
		$found = $true
	}
	else
	{
		Write-Host "SSL PROFILE NOT present..." -ForegroundColor Yellow
		$found = $false
	}

	return $found
}

function new-sslprofile ($sslprofile,$dhname) {
	$body = ConvertTo-Json @{
		"sslprofile" = @{
			"name" = $sslprofile;
			"sslprofiletype" = "FrontEnd";
			"dh" = "ENABLED";
			"dhcount" = "0";
			"dhfile" = $dhname;
			"ersa" = "ENABLED";
			"ersacount" = "0";
			"sessreuse" = "ENABLED";
			"sesstimeout" = "120";
			"cipherredirect" = "DISABLED";
			"clientauth" = "DISABLED";
			"sslredirect" = "DISABLED";
			"redirectportrewrite" = "DISABLED";
			"nonfipsciphers" = "DISABLED";
			"ssl3" = "DISABLED";
			"tls1" = "ENABLED";
			"tls11" = "ENABLED";
			"tls12" = "ENABLED";
			"snienable" = "DISABLED";
			"ocspstapling" = "DISABLED";
			"serverauth" = "DISABLED";
			"pushenctrigger" = "Always";
			"sendclosenotify" = "YES";
			"insertionencoding" = "Unicode";
			"denysslreneg" = "FRONTEND_CLIENT";
			"quantumsize" = "8192";
			"strictcachecks" = "NO";
			"encrypttriggerpktcount" = "45";
			"pushflag" = "0";
			"dropreqwithnohostheader" = "NO";
			"pushenctriggertimeout" = "1";
			"ssltriggertimeout" = "100";
			"clientauthuseboundcachain" = "DISABLED";
			"sessionticket" = "DISABLED";
			"sessionticketlifetime" = "300";
		}
	}

	Invoke-RestMethod -Uri "$hostname/nitro/v1/config/sslprofile" -Body $body -WebSession $NSSession -Headers @{ "Content-Type" = "application/json" } -Method POST | Out-Null
}

function set-profilecipherbinding ($name,$cipher)
{
	Write-Host "Binding $cipher" -ForegroundColor Yellow
	$body = ConvertTo-Json @{
		"sslprofile_sslcipher_binding" = @{
			"name" = "$Name";
			"ciphername" = "$Cipher";
		}
	}
	Invoke-RestMethod -Uri "$hostname/nitro/v1/config/sslprofile_sslcipher_binding/$Name" -Body $body -WebSession $NSSession `
 		-Headers @{ "Content-Type" = "application/json" } -Method PUT | Out-Null

}

function set-profilecipher ($name,$cipher)
{
	#unbinds all cipher groups
	$foundflag = 0 #flag if cipher already found
	$cgs = Invoke-RestMethod -Uri "$hostname/nitro/v1/config/sslprofile_sslcipher_binding/$name" -WebSession $NSSession `
 		-Headers @{ "Content-Type" = "application/json" } -Method GET

	$cgs = $cgs.sslprofile_sslcipher_binding

	#Check for cipher
	$found = 0
	foreach ($cg in $cgs)
	{

		if ($cg.cipheraliasname -like $cipher)
		{
			Write-Host "Cipher Present"
			$found = 1
		}

	}

	if ($found -eq 0)
	{
		#binds new cipher group created if not already present
		set-profilecipherbinding -Name $name -cipher $cipher
	}


	#Remove other ciphers
	foreach ($cg in $cgs)
	{

		if ($cg.cipheraliasname -notlike $cipher)
		{
			Write-Host "Unbinding" $cg.cipheraliasname -ForegroundColor yellow

			Invoke-RestMethod -Uri ("$hostname/nitro/v1/config/sslprofile_sslcipher_binding/$Name" + "?args=cipherName:" + $cg.cipheraliasname) -WebSession $NSSession `
 				-Headers @{ "Content-Type" = "application/vnd.com.citrix.netscaler.sslservice_sslciphersuite_binding+json" } -Method DELETE | Out-Null
		}

	}


}


###Script starts here

#Logs into netscaler
Write-Host "Logging in..."
Login

#Checks for supported NS firmware version (10.5)
$version = check-nsversion
switch ($version)
{
	{ $_ -lt 10.5 }
	{
		throw "Netscaler firmware version MUST be greater than 10.5"
		exit
	}
	{ $_ -lt "11.0.64.34" }
	{
		Write-Host "$($version.ToString()) has been detected. Default SSL profile not supported."
		$useprofile = $false
		if ($sslprofile -notlike "custom-ssllabs-profile" -or $enablesslprof)
		{
			Write-Host "SSL PROFILE IGNORED DUE TO FIRMARE VERSION" -ForegroundColor Yellow
		}
	}
	{ $_ -ge "11.0.64.34" }
	{
		Write-Host "$($version.ToString()) has been detected. Default SSL profile supported."

		#Check for SSL default profile. Might do something around legacy in the future
		$testprof = check-defaultprofile
		if ($testprof -like "ENABLED")
		{
			Write-Host "DEFAULT SSL PROFILE IS ENABLED." -ForegroundColor GREEN
			$useprofile = $true
		}
		elseif ($testprof -like "DISABLED" -and $enablesslprof)
		{
			Write-Host "Enabling Default Profile Feature" -ForegroundColor Gray
			$useprofile = $true
			enable-sslprof
		}
		else
		{
			Clear-Host
			Write-Host '"Default SSL Profile" is recommended for 11.0.64.34 or greater.  Running in LEGACY mode for this run.' -ForegroundColor Yellow
			Write-Host 'See https://docs.citrix.com/en-us/netscaler/11-1/ssl/ssl-profiles1/ssl-enabling-the-default-profile.html' -ForegroundColor yellow
			Write-Host 'Can enable with the -enablesslprof switch OR manually' -ForegroundColor Yellow
			Write-Host 'CLI: set ssl parameter -defaultProfile ENABLED' -ForegroundColor Yellow
			Write-Host 'GUI: Traffic Management > SSL > Change advanced SSL settings, scroll down, and select Enable Default Profile.' -ForegroundColor Yellow
			Start-Sleep -Seconds 5
			$useprofile = $false
		}

	}
}

Write-Host "Checking for DHKEY: " $dhname -ForegroundColor White
#Checks for and creates DH key
if ((checkfordhkey $dhname) -eq $false)
{
	Write-Host "DHKEY creation in process.  Can take a couple of minutes..." -ForegroundColor yellow
	new-dhkey $dhname
}

Write-Host "Checking for cipher group..." -ForegroundColor White
#Checks for cipher group we will be creating    
if (((get-ciphers).ciphergroupname) -notcontains $ciphergroupname)
{
	Write-Host "Creating" $ciphergroupname -ForegroundColor Gray
	if (checkvpx)
	{
		Write-Host "Creating cipher group for VPX..."
		CipherGroup-vpx $ciphergroupname
	}
	else
	{
		Write-Host "Creating cipher group for NON-VPX..."
		ciphergroup $ciphergroupname
	}
}
else
{
	Write-Host $ciphergroupname "already present" -ForegroundColor Green
}

Write-Host "Checking for rewrite policy..." -ForegroundColor White
#Checks for rewrite policy
if (((get-rewritepol).Name) -notcontains $rwpolname)
{
	Write-Host "Creating " $rwpolname -ForegroundColor Gray
	SetupSTS $rwactname $rwpolname
}
else
{
	Write-Host $rwpolname "already present" -ForegroundColor Green
}

#Checking for SSL profile and creating if needed
if ($useprofile)
{
	Write-Host "Checking for SSL Profile..." -ForegroundColor White
	if ((check-sslprofile -sslprofile $sslprofile) -eq $false)
	{
		Write-Host "Creating SSL Profile $sslprofile" -ForegroundColor Gray
		new-sslprofile $sslprofile $dhname
		Write-Host "Binding Cipher Group" -ForegroundColor Gray
		set-profilecipher $sslprofile $ciphergroupname
	}


}


if ($mgmt)
{
	Write-Host "Adjusting SSL managment IPs..." -ForegroundColor White
	#adjusts all managment IPs.  Does not adjust ciphers
	set-nsip

}
else
{
	Write-Host "Skipping SSL managment IPs..."
}

if ($nolb)
{
	Write-Host "Skipping LB VIPs..." -ForegroundColor White
}
else
{
	Write-Host "Checking LB VIPs..." -ForegroundColor White
	#Gets all LB servers that are SSL and makes changes
	$lbservers = (get-vservers)
	$ssls = $lbservers | Where-Object { $_.servicetype -like "SSL" }

	foreach ($ssl in $ssls) {
		Write-Host $ssl.Name
		(set-cipher $ssl.Name $ciphergroupname)
		if ($useprofile)
		{
			set-sslprofilebind $ssl.Name $sslprofile
		}
		Write-Host "Binding STS policy"
		set-lbpols $ssl $rwpolname $rwpolpri
	}
}

if ($novpn)
{
	Write-Host "Skiping VPN VIPS..."
}
else
{
	Write-Host "Checking VPN VIPs..." -ForegroundColor White
	#Gets all Netscaler Gateways and makes changes
	$vpnservers = get-vpnservers

	foreach ($ssl in $vpnservers) {
		Write-Host $ssl.Name
		if ($useprofile)
		{
			set-sslprofilebind $ssl.Name $sslprofile
		}
		(set-cipher $ssl.Name $ciphergroupname)
		Write-Host "Binding STS policy"
		set-vpnpols $ssl $rwpolname $rwpolpri
	}
}


if ($nocsw)
{
	Write-Host "Skipping CSW IPs..." -ForegroundColor White
}
else
{
	Write-Host "Checking CS VIPs..." -ForegroundColor White
	#Gets all Content Switches and makes changes
	$csservers = get-csservers
	#Filters for only SSL
	$csssls = $csservers | Where-Object { $_.servicetype -like "SSL" }
	foreach ($sslcs in $csssls) {
		Write-Host $sslcs.Name
		if ($useprofile)
		{
			set-sslprofilebind $sslcs.Name $sslprofile
		}
		(set-cipher $sslcs.Name $ciphergroupname)
		Write-Host "Binding STS policy"
		set-cspols $sslcs $rwpolname $rwpolpri
	}
}

#SSL Global Params
if ($noneg -or $useprofile -eq $true)
{
	Write-Host "Skipping SSL global renegotiation..." -ForegroundColor White
}
else
{
	Write-Host "Setting SSL global renegotiation..." -ForegroundColor White
	set-sslparams
}

#Save config
if ($nosave)
{
	Write-Host "NOT saving NS config.." -ForegroundColor White
}
else
{
	Write-Host "Saving NS config.." -ForegroundColor White
	#Save NS Config
	SaveConfig
}

Write-Host "Logging out..." -ForegroundColor White
#Logout
Logout
