#Downloads Citrix CVAD 1906 Workstation VDA
#Can be used as part of a pipeline or MDT task sequence.
#Ryan Butler TechDrabble.com @ryan_c_butler 07/19/2019

#Uncomment to use plain text or env variables
#$CitrixUserName = $env:citrixusername
#$CitrixPassword = $env:citrixpassword

#Uncomment to use credential object
$creds = Get-Credential
$CitrixUserName = $creds.UserName
$CitrixPassword = $creds.GetNetworkCredential().Password

$downloadpath = "C:\temp\VDAWorkstationSetup_1906.exe"

#Initialize Session 
Invoke-WebRequest "https://identity.citrix.com/Utility/STS/Sign-In?ReturnUrl=%2fUtility%2fSTS%2fsaml20%2fpost-binding-response" -SessionVariable websession -UseBasicParsing

#Set Form
$form = @{
	"persistent" = "on"
	"userName" = $CitrixUserName
	"password" = $CitrixPassword
}

#Authenticate
Invoke-WebRequest -Uri ("https://identity.citrix.com/Utility/STS/Sign-In?ReturnUrl=%2fUtility%2fSTS%2fsaml20%2fpost-binding-response") -WebSession $websession -Method POST -Body $form -ContentType "application/x-www-form-urlencoded" -UseBasicParsing

$download = Invoke-WebRequest -Uri ('https://secureportal.citrix.com/Licensing/Downloads/UnrestrictedDL.aspx?DLID=16111&URL=https://downloads.citrix.com/16111/VDAWorkstationSetup_1906.exe') -WebSession $websession -UseBasicParsing -Verbose -Method GET
$webform = @{
	"chkAccept" = "on"
	"__EVENTTARGET" = "clbAccept_0"
	"__EVENTARGUMENT" = "clbAccept_0_Click"
	"__VIEWSTATE" = ($download.InputFields | Where-Object { $_.id -eq "__VIEWSTATE" }).value
	"__EVENTVALIDATION" = ($download.InputFields | Where-Object { $_.id -eq "__EVENTVALIDATION" }).value
}

#Download
Invoke-WebRequest -Uri ("https://secureportal.citrix.com/Licensing/Downloads/UnrestrictedDL.aspx?DLID=16111&URL=https://downloads.citrix.com/16111/VDAWorkstationSetup_1906.exe") -WebSession $websession -Method POST -Body $webform -ContentType "application/x-www-form-urlencoded" -UseBasicParsing -OutFile $downloadpath -Verbose

