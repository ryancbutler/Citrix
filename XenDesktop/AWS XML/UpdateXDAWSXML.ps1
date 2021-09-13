#Creates an XML file with updated EC2 Instance info https://support.citrix.com/article/CTX139707

#Region to pull
$region = "us-east-1";
$xmllocation = "$PSScriptRoot\InstanceTypes.xml"

#XML template
[xml]$awsxml = @"
<?xml version="1.0" encoding="UTF-8"?>

<!--
AWS Instance Types

This configuration file describes the AWS instance types.

AWS instance types are documented by Amazon, but they are not available through the API, so XenDesktop services
are unable to discover them dynamically at run time. This configuration file stores the descriptions in such a way
that they can be ammended manually.

As with all system configuration formats, this file must be edited with care. Please ensure that the rules of the
XSD schema file are followed. (The XSD schema file can be found in the same folder as this XML file within your
installation.) Mistakes in this file could result in no service offerings being available for AWS-based cloud
connections, or in exceptions being thrown from the Citrix Host Service.

-->

<InstanceTypes xmlns="http://www.citrix.com/2013/xd/AWSInstanceTypes"
               xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
               xsi:schemaLocation="http://www.citrix.com/2013/xd/AWSInstanceTypes InstanceTypes.xsd">

</InstanceTypes>
"@

$config = $awsxml.instancetypes

write-host "Getting instance types from AWS..."
$return = Invoke-RestMethod -Method Get -Uri "https://pricing.$region.amazonaws.com/offers/v1.0/aws/AmazonEC2/current/$region/index.json"

$products = @()

$return.products.psobject.Properties | ForEach-Object { $products += $_.value }

$products = $products | Where-Object { $_.Attributes.currentGeneration -eq "Yes" -and $_.Attributes.operatingsystem -eq "Windows" } | Select-Object attributes -ExpandProperty attributes | Sort-Object instanceType -Unique

foreach ($prod in $products) {
	$attr = $prod
	write-host $attr.instanceType
	
	$mem = ($attr.memory) -replace " GiB", ""
	[decimal]$mem = ($mem) -replace ",", ""
	$mem = $mem * 1024

	$add = $awsxml.CreateElement('InstanceType', $config.NamespaceURI)
	$instance = $config.AppendChild($add)

	$inner = $awsxml.CreateElement('Name', $instance.NamespaceURI)
	$inner = $instance.AppendChild($inner)
	$inner.InnerText = "$($attr.instanceType) (vCPU:$($attr.vcpu))"

	$inner = $awsxml.CreateElement('MemoryMiB', $instance.NamespaceURI)
	$inner = $instance.AppendChild($inner)
	$inner.InnerText = $mem

	if ($attr.ecu -eq "Variable") {
		$ecu = 0 #this ranges way to much and shouldn't even be used in my opinion
	}
	else {
		$ecu = $attr.ecu
	}

	$inner = $awsxml.CreateElement('EC2ComputeUnits', $instance.NamespaceURI)
	$inner = $instance.AppendChild($inner)
	$inner.InnerText = $ecu -replace "NA", "0"

	$inner = $awsxml.CreateElement('VirtualCores', $instance.NamespaceURI)
	$inner = $instance.AppendChild($inner)
	$inner.InnerText = $attr.vcpu

	$inner = $awsxml.CreateElement('InstanceStorageGB', $instance.NamespaceURI)
	$inner = $instance.AppendChild($inner)
	$inner.InnerText = "100"

	if ($attr.processorArchitecture -eq "64-bit") {
		$inner = $awsxml.CreateElement('Platform32', $instance.NamespaceURI)
		$inner = $instance.AppendChild($inner)
		$inner.InnerText = 'false'
		$inner = $awsxml.CreateElement('Platform64', $instance.NamespaceURI)
		$inner = $instance.AppendChild($inner)
		$inner.InnerText = 'true'
	}
	else {
		$inner = $awsxml.CreateElement('Platform32', $instance.NamespaceURI)
		$inner = $instance.AppendChild($inner)
		$inner.InnerText = 'true'
		$inner = $awsxml.CreateElement('Platform64', $instance.NamespaceURI)
		$inner = $instance.AppendChild($inner)
		$inner.InnerText = 'true'
	}

	#can't grab from api
	$inner = $awsxml.CreateElement('IOPerformance', $instance.NamespaceURI)
	$inner = $instance.AppendChild($inner)
	$inner.InnerText = 'High'

	#can't grab from api
	$inner = $awsxml.CreateElement('EBSOptimizedAvailable', $instance.NamespaceURI)
	$inner = $instance.AppendChild($inner)
	$inner.InnerText = 'true'

	$inner = $awsxml.CreateElement('APIName', $instance.NamespaceURI)
	$inner = $instance.AppendChild($inner)
	$inner.InnerText = $attr.instanceType

	$inner = $awsxml.CreateElement('NetworkPerformance', $instance.NamespaceURI)
	$inner = $instance.AppendChild($inner)
	$inner.InnerText = $attr.networkPerformance

}
$awsxml.Save($xmllocation)
