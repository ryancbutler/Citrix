<#
.SYNOPSIS
   Getting started with App Layering API service
.DESCRIPTION
   Getting started with App Layering API service
.NOTES 
   Twitter: ryan_c_butler
   Website: Techdrabble.com
   Created: 10/29/2019
.LINK
   https://github.com/ryancbutler/UnifiAPI
#>


#Cloud ID name
$customerid = "mycustomeridname"

#APP LAYERING ENDPOINT
#https://us.workstreams.cloud.com/services/Citrix.AppLayering/master/LayeringServices
#https://eu.workstreams.cloud.com/services/Citrix.AppLayering/master/LayeringServices
#https://ap-s.workstreams.cloud.com/services/Citrix.AppLayering/master/LayeringServices

$rootUrl = "https://us.workstreams.cloud.com/services/Citrix.AppLayering/master/LayeringServices"

#Citrix Cloud API creds
$id = "cea2cdb5-...."
$secret = "3c...."

#ELM Admincreds
$elmip = "192.168.2.50"
$elmuser = "administrator"
$elmpw = "mypassword"

#API Agent Registration ID
$resourceLocationId = "getfromapiappliance"

function Get-BearerToken {
  param (
    [Parameter(Mandatory = $true)]
    [string] $customerId,
    [Parameter(Mandatory = $true)]
    [string] $clientId,
    [Parameter(Mandatory = $true)]
    [string] $secret
  )
  $requestUri = "https://trust.citrixworkspacesapi.net/$customerId/tokens/clients"
  $headers = @{"Content-Type" = "application/json" }
  
  $auth = @{
    "ClientId"     = $clientId
    "ClientSecret" = $secret
  }

  $response = Invoke-RestMethod -Uri $requestUri -Method POST -Headers $headers -Body (ConvertTo-Json $auth)
  return $response.token
}

function Invoke-ApplianceReg {
  param (
    [Parameter(Mandatory = $true)]
    [string] $customerId,
    [Parameter(Mandatory = $true)]
    [string] $token,
    [Parameter(Mandatory = $true)]
    [string] $url
  )
  $requestUri = $url + "/resources/"
  $headers = @{
    "Content-Type"      = "application/json; charset=utf-8"
    "Authorization"     = "CWSAuth bearer=$token"
    "Accept"            = "application/json;version=preview"
    "Citrix-CustomerId" = $customerId
  }

  $body = @{
    "name"                = "My cool Appliance"
    "description"         = "A description of my App Layering appliance"
    "type"                = "Appliance"
    "resourceLocationId"  = $resourceLocationId
    "applianceConnection" = @{
      "address" = $elmip
      "auth"    = @{
        "credentials" = @{
          "username" = $elmuser
          "password" = $elmpw
        }
      }
    }
  }
  

  $response = Invoke-RestMethod -Uri $requestUri -Method POST -Headers $headers -Body ($body | ConvertTo-Json -Depth 5)
  return $response
}

function Invoke-ApplianceSync {
  param (
    [Parameter(Mandatory = $true)]
    [string] $customerId,
    [Parameter(Mandatory = $true)]
    [string] $token,
    [Parameter(Mandatory = $true)]
    [string] $url,
    [Parameter(Mandatory = $true)]
    [string] $ApplianceID
  )
  
  $headers = @{
    "Content-Type"      = "application/json; charset=utf-8"
    "Authorization"     = "CWSAuth bearer=$token"
    "Accept"            = "application/json;version=preview"
    "Citrix-CustomerId" = $customerId
  }

  $requestUri = $url + "/resources/" + $ApplianceID + "/`$sync?async=true"

  $response = Invoke-WebRequest -Uri $requestUri -Method POST -Headers $headers
  return $response.headers.Location
}

function Get-ApplianceResource {
  param (
    [Parameter(Mandatory = $true)]
    [string] $customerId,
    [Parameter(Mandatory = $true)]
    [string] $token,
    [Parameter(Mandatory = $true)]
    [string] $url,
    [Parameter(Mandatory = $false)]
    [string] $ApplianceID
  )
  
  $headers = @{
    "Content-Type"      = "application/json; charset=utf-8"
    "Authorization"     = "CWSAuth bearer=$token"
    "Accept"            = "application/json;version=preview"
    "Citrix-CustomerId" = $customerId
  }

  $requestUri = $url + "/resources/" + $ApplianceID

  $response = Invoke-RestMethod -Uri $requestUri -Method GET -Headers $headers
  if ($response.items) {
    return $response.items
  }
  else {
    return $response
  }

}

function Get-ApplianceJobs {
  param (
    [Parameter(Mandatory = $true)]
    [string] $customerId,
    [Parameter(Mandatory = $true)]
    [string] $token,
    [Parameter(Mandatory = $true)]
    [string] $url
  )
  
  $headers = @{
    "Content-Type"      = "application/json; charset=utf-8"
    "Authorization"     = "CWSAuth bearer=$token"
    "Accept"            = "application/json;version=preview"
    "Citrix-CustomerId" = $customerId
  }

  $requestUri = $url + "/jobs"

  $response = Invoke-RestMethod -Uri $requestUri -Method GET -Headers $headers

  return $response.items


}

function Get-ApplianceLayers {
  param (
    [Parameter(Mandatory = $true)]
    [string] $customerId,
    [Parameter(Mandatory = $true)]
    [string] $token,
    [Parameter(Mandatory = $true)]
    [string] $url
  )
  
  $headers = @{
    "Content-Type"      = "application/json; charset=utf-8"
    "Authorization"     = "CWSAuth bearer=$token"
    "Accept"            = "application/json;version=preview"
    "Citrix-CustomerId" = $customerId
  }

  $requestUri = $url + "/Layers"

  $response = Invoke-RestMethod -Uri $requestUri -Method GET -Headers $headers

  return $response.items

}


#Get Initial Token
$token = Get-BearerToken -customerid $customerid -secret $secret -clientId $id

#Register appliance and get appliance ID
$applianceID = Invoke-ApplianceReg -customerId $customerid -token $token -url $rootUrl

#Get appliance info
get-applianceresource -customerId $customerid -token $token -url $rootUrl -ApplianceID $applianceID.id

#Invoke appliance Synce
Invoke-ApplianceSync -customerId $customerid -token $token -url $rootUrl -ApplianceID $applianceID.id

#Once Job is complete there should be more info
get-applianceresource -customerId $customerid -token $token -url $rootUrl -ApplianceID $applianceID.id

#Get running jobs
get-appliancejobs -customerId $customerid -token $token -url $rootUrl

#Get Layers
get-applianceLayers -customerId $customerid -token $token -url $rootUrl
