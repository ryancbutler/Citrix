<#
.SYNOPSIS
   Grabs Citrix Netscaler version info to compare against https://support.citrix.com/article/CTX227928
.DESCRIPTION
   Grabs Citrix Netscaler version info to compare against https://support.citrix.com/article/CTX227928
.PARAMETER nsip
   DNS Name or IP of the Netscaler that needs to be configured. (MANDATORY)
.PARAMETER adminaccount
   Netscaler admin account (Default: nsroot)
.PARAMETER adminpassword
   Password for the Netscaler admin account (Default: nsroot)
.PARAMETER https
   Use HTTPS for communication
.EXAMPLE
    "192.168.1.6","192.168.2.6"|.\Netscaler\CTX227928.ps1
    Pipes NSIP info and returns version
.Example
    \Netscaler\CTX227928.ps1 -nsip "192.168.1.6"
    Grabs version from single NSIP
.Example
    \Netscaler\CTX227928.ps1 -nsip "192.168.1.6" adminaccount nsroot -adminpassword mysecretpassword
    Grabs version from single NSIP
.Example
    \Netscaler\CTX227928.ps1 -nsip "192.168.1.6" -https
    Grabs version from single NSIP using HTTPS (requires TLS1-ECDHE-RSA-AES256-SHA at least)
#>
[CmdletBinding()]
param
(
	[Parameter(Mandatory = $true,ValueFromPipeline = $true,ValueFromPipelineByPropertyName = $true)] $nsip,
	[string]$adminaccount = "nsroot",
	[string]$adminpassword = "nsroot",
	[switch]$https
)

begin {
	function Login-ns ($hostname) {
		# Login to NetScaler and save session to global variable
		$body = ConvertTo-Json @{
			"login" = @{
				"username" = "$adminaccount";
				"password" = "$adminpassword"
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

	function Logout-ns {
		#logs out of Netscaler
		$body = ConvertTo-Json @{
			"logout" = @{
			}
		}
		Invoke-RestMethod -Uri "$hostname/nitro/v1/config/logout" -Body $body -WebSession $NSSession `
 			-Headers @{ "Content-Type" = "application/vnd.com.citrix.netscaler.logout+json" } -Method POST | Out-Null
	}

	function check-nsversion {
		$info = Invoke-RestMethod -Uri "$hostname/nitro/v1/config/nsversion" -WebSession $NSSession `
 			-Headers @{ "Content-Type" = "application/json" } -Method GET
		$version = $info.nsversion.version
		return $version
	}
}

process {
	if ($https)
	{
		[System.Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls
		[System.Net.ServicePointManager]::ServerCertificateValidationCallback = { $true }
		Write-Verbose "Connecting HTTPS"
		$hostname = "https://" + $nsip
	}
	else
	{
		Write-Verbose "Connecting HTTP"
		$hostname = "http://" + $nsip
	}
	login-ns $hostname
	$nsversion = New-Object PSCustomObject
	$nsversion | Add-Member -NotePropertyName "NSIP" -NotePropertyValue $nsip
	$nsversion | Add-Member -NotePropertyName "VERSION" -NotePropertyValue (check-nsversion)
	return $nsversion
	Logout-ns
}
