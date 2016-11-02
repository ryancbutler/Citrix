#PowerShell script for XM ShareFile workaround https://support.citrix.com/article/CTX218470
#Ryan Butler 11-2-2016

$login = "administrator"
$password = "password"
$xmserver = "192.168.1.5:4443"
#Run SQL query to get needed ID FIRST
#(select ID,Name from RESOURCES_BAG where resources_bag.type like 'APP_FMD')
$sfid = ""

######SCRIPT

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls
[System.Net.ServicePointManager]::ServerCertificateValidationCallback = {$true}

$body = ConvertTo-JSON @{
            "login"="$login";
            "password"="$password"}

$token = Invoke-RestMethod -uri "https://$xmserver/xenmobile/api/v1/authentication/login" -body $body -Headers @{"Content-Type"="application/json"} -Method POST

Invoke-RestMethod -uri "https://$xmserver/xenmobile/api/v1/application/$sfid" -Headers @{"auth_token"=$token.auth_token} -Method DELETE


