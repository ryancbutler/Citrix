#Creates an XML file with updated EC2 Instance info https://support.citrix.com/article/CTX139707

$xmllocationtemp = "$PSScriptRoot\InstanceTypes-template.xml"
$xmllocation = "$PSScriptRoot\InstanceTypes.xml"

$awsxml = New-Object System.Xml.XmlDocument
$awsxml.Load($xmllocationtemp)
$config = $awsxml.instancetypes

$return = Invoke-RestMethod -Method Get -Uri "https://pricing.us-east-1.amazonaws.com/offers/v1.0/aws/AmazonEC2/current/us-east-1/index.json"

$products= @()

$return.products.psobject.Properties|%{$products += $_.value}

$products = $products|where{$_.attributes.currentGeneration -eq "Yes" -and $_.attributes.operatingsystem -eq "Windows"}

foreach ($prod in $products)
{
  $attr = $prod.attributes
  
  $mem = ($attr.memory) -replace " GiB",""
  [decimal]$mem = ($mem) -replace ",",""
  $mem = $mem * 1024

  $add = $awsxml.CreateElement('InstanceType',$config.NamespaceURI)
  $instance = $config.AppendChild($add)
  
    $inner = $awsxml.CreateElement('Name',$instance.NamespaceURI)
    $inner = $instance.AppendChild($inner)
    $inner.InnerText = "$($attr.instanceType) (vCPU:$($attr.vcpu))"

    $inner = $awsxml.CreateElement('MemoryMiB',$instance.NamespaceURI)
    $inner = $instance.AppendChild($inner)
    $inner.InnerText = $mem

    if ($attr.ecu -eq "Variable")
    {
      $ecu = 0 #this ranges way to much and shouldn't even be used in my opinion
    }
    else
    {
      $ecu = $attr.ecu
    }
    $inner = $awsxml.CreateElement('EC2ComputeUnits',$instance.NamespaceURI)
    $inner = $instance.AppendChild($inner)
    $inner.InnerText = $ecu

    $inner = $awsxml.CreateElement('VirtualCores',$instance.NamespaceURI)
    $inner = $instance.AppendChild($inner)
    $inner.InnerText = $attr.vcpu

    $inner = $awsxml.CreateElement('InstanceStorageGB',$instance.NamespaceURI)
    $inner = $instance.AppendChild($inner)
    $inner.InnerText = "100"
    
    if ($attr.processorArchitecture -eq "64-bit")
    {
      $inner = $awsxml.CreateElement('Platform32',$instance.NamespaceURI)
      $inner = $instance.AppendChild($inner)
      $inner.InnerText = 'false'
      $inner = $awsxml.CreateElement('Platform64',$instance.NamespaceURI)
      $inner = $instance.AppendChild($inner)
      $inner.InnerText = 'true'    
    }
    else {
      $inner = $awsxml.CreateElement('Platform32',$instance.NamespaceURI)
      $inner = $instance.AppendChild($inner)
      $inner.InnerText = 'true'
      $inner = $awsxml.CreateElement('Platform64',$instance.NamespaceURI)
      $inner = $instance.AppendChild($inner)
      $inner.InnerText = 'true'   
    }

    #can't grab from api
    $inner = $awsxml.CreateElement('IOPerformance',$instance.NamespaceURI)
    $inner = $instance.AppendChild($inner)
    $inner.InnerText = 'High'
  
    #can't grab from api
    $inner = $awsxml.CreateElement('EBSOptimizedAvailable',$instance.NamespaceURI)
    $inner = $instance.AppendChild($inner)
    $inner.InnerText = 'true'

    $inner = $awsxml.CreateElement('APIName',$instance.NamespaceURI)
    $inner = $instance.AppendChild($inner)
    $inner.InnerText = $attr.instanceType

    $inner = $awsxml.CreateElement('NetworkPerformance',$instance.NamespaceURI)
    $inner = $instance.AppendChild($inner)
    $inner.InnerText = $attr.networkPerformance

}
$awsxml.Save($xmllocation)