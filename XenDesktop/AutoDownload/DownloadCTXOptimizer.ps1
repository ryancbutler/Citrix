#Downloads Latest Citrix Opimizer from https://support.citrix.com/article/CTX224676
#Can be used as part of a pipeline or MDT task sequence.
#Ryan Butler TechDrabble.com @ryan_c_butler 07/19/2019

#Uncomment to use plain text or env variables
#$CitrixUserName = $env:citrixusername
#$CitrixPassword = $env:citrixpassword

#Uncomment to use credential object
$creds = get-credential
$CitrixUserName = $creds.UserName
$CitrixPassword = $creds.GetNetworkCredential().Password

$downloadpath = "C:\temp\CitrixOptimizer.zip"
$unzippath = "C:\temp\opt"

#Initialize Session 
$R=Invoke-WebRequest "https://identity.citrix.com/Utility/STS/Sign-In" -SessionVariable websession

#Set Form
$form = $R.Forms[0]
$form.Fields["persistent"]="1"
$form.Fields["userName"]= $CitrixUserName
$form.Fields["loginbtn"]=""
$form.Fields["password"]= $CitrixPassword
$form.Fields["returnURL"]="https://www.citrix.com/login/bridge?url=https%3A%2F%2Fsupport.citrix.com%2Farticle%2FCTX224676%3Fdownload"
$form.Fields["errorURL"]='https://www.citrix.com/login?url=https%3A%2F%2Fsupport.citrix.com%2Farticle%2FCTX224676%3Fdownload&err=y'

#Authenticate
$R=Invoke-WebRequest -Uri ("https://identity.citrix.com/Utility/STS/Sign-In") -WebSession $websession -Method POST -Body $form.Fields -contentType "application/x-www-form-urlencoded" -UseBasicParsing

#Download File
Invoke-WebRequest -WebSession $websession -Uri "https://phoenix.citrix.com/supportkc/filedownload?uri=/filedownload/CTX224676/CitrixOptimizer.zip" -OutFile $downloadpath -Verbose

#Unzip Optimizer. Requires 7-zip!
7z.exe x $downloadpath -o"$unzippath" -y
