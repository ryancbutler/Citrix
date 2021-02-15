#Downloads Latest Citrix Opimizer from https://support.citrix.com/article/CTX224676
#Can be used as part of a pipeline or MDT task sequence.
#Ryan Butler TechDrabble.com @ryan_c_butler 07/19/2019

#Uncomment to use plain text or env variables
#$CitrixUserName = $env:citrixusername
#$CitrixPassword = $env:citrixpassword

#Uncomment to use credential object
$creds = Get-Credential
$CitrixUserName = $creds.UserName
$CitrixPassword = $creds.GetNetworkCredential().Password

$downloadpath = "C:\temp\CitrixOptimizer.zip"
$unzippath = "C:\temp\opt"

#Initialize Session 
Invoke-WebRequest "https://identity.citrix.com/Utility/STS/Sign-In" -SessionVariable websession -UseBasicParsing

#Set Form
$form = @{
	"persistent" = "1"
	"userName" = $CitrixUserName
	"loginbtn" = ""
	"password" = $CitrixPassword
	"returnURL" = "https://login.citrix.com/bridge?url=https://support.citrix.com/article/CTX224676"
	"errorURL" = "https://login.citrix.com?url=https://support.citrix.com/article/CTX224676&err=y"
}
#Authenticate
Invoke-WebRequest -Uri ("https://identity.citrix.com/Utility/STS/Sign-In") -WebSession $websession -Method POST -Body $form -ContentType "application/x-www-form-urlencoded" -UseBasicParsing

#Download File
Invoke-WebRequest -WebSession $websession -Uri "https://fileservice.citrix.com/download/secured/support/article/CTX224676/downloads/CitrixOptimizer.zip" -OutFile $downloadpath -Verbose -UseBasicParsing

#Unzip Optimizer. Requires 7-zip!
7z.exe x $downloadpath -o"$unzippath" -y
