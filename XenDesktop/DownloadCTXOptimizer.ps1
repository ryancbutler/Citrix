#Downloads Latest Citrix Opimizer from https://support.citrix.com/article/CTX224676
#Can be used as part of a pipeline or MDT task sequence.
#Ryan Butler TechDrabble.com @ryan_c_butler 07/19/2019

$CitrixUserName = "myusername"
$CitrixPassword =  "mypassword"

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
Invoke-WebRequest -WebSession $websession -Uri "https://phoenix.citrix.com/supportkc/filedownload?uri=/filedownload/CTX224676/CitrixOptimizer.zip" -OutFile "CitrixOptimizer.zip"
