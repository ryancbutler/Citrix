#PowerShell script for XM ShareFile workaround https://support.citrix.com/article/CTX218470
#Ryan Butler 11-2-2016

#XenMobile server information
$login = "administrator"
$password = "password"
$xmserver = "192.168.1.5:4443"

#Either Run SQL query to get needed ID FIRST or set runsql=true to run query from script with Windows Authentication
#select ID,Name from RESOURCES_BAG where resources_bag.type like 'APP_FMD'
$sfid = "" #set if not setting $runsql=$true

$runsql = $false #Set to $true to run SQL query from script.  Uses Windows authentication
[string] $dataSource = "sqlserver" #SQL Server
[string] $database = "xenmobiledb" #XM Database name

######SCRIPT

function get-sfid {

        
    [string] $sqlCommand = "select ID,Name from RESOURCES_BAG where resources_bag.type like 'APP_FMD'"


    $connectionString = "Data Source=$dataSource; " +
            "Integrated Security=SSPI; " +
            "Initial Catalog=$database"

    $connection = new-object system.data.SqlClient.SQLConnection($connectionString)
    $command = new-object system.data.sqlclient.sqlcommand($sqlCommand,$connection)
    $connection.Open()

    $adapter = New-Object System.Data.sqlclient.sqlDataAdapter $command
    $dataset = New-Object System.Data.DataSet
    $adapter.Fill($dataSet) | Out-Null

    $connection.Close()
    $dataSet.Tables

}


if ($runsql)
{
    $sfid =  (get-sfid).id
}

if(!$sfid)
{
    throw "APP ID NOT FOUND. Check Script or APP ID has already been removed."
    break
}

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls
[System.Net.ServicePointManager]::ServerCertificateValidationCallback = {$true}

$body = ConvertTo-JSON @{
            "login"="$login";
            "password"="$password"}

$token = Invoke-RestMethod -uri "https://$xmserver/xenmobile/api/v1/authentication/login" -body $body -Headers @{"Content-Type"="application/json"} -Method POST


Invoke-RestMethod -uri "https://$xmserver/xenmobile/api/v1/application/$sfid" -Headers @{"auth_token"=$token.auth_token} -Method DELETE