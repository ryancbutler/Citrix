#Example script to download multiple VDA and ISO versions from Citrix.com
#Ryan Butler 2/6/2020

#Import Download Function
. ./Helpers/Get-CTXBinary.ps1

#Uncomment to use credential object
$creds = Get-Credential
$CitrixUserName = $creds.UserName
$CitrixPassword = $creds.GetNetworkCredential().Password

#Imports CSV with download information
$downloads = import-csv -Path ".\Helpers\Downloads.csv" -Delimiter ","

#Use CTRL to select multiple
$dls = $downloads | Out-GridView -PassThru

#Processes each download
foreach ($dl in $dls) {
    Get-CTXBinary -DLNUMBER $dl.dlnumber -DLEXE $dl.filename -CitrixUserName $CitrixUserName -CitrixPassword $CitrixPassword -DLPATH $path
}