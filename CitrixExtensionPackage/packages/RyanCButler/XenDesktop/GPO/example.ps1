CLS
$module = "C:\Temp\Citrix.GroupPolicy.Commands.psm1"
#Path for XML Policy Exports
$exportpath = "C:\temp\exported"
#AD Group Policy Name
$GPOName = "CITRIX - GPO TEST 4"

#Need Citrix Snapins.  Run from Citrix DDC
#Add-PSSnapin citrx*

Import-Module $module -force
New-PSDrive -Name LocalFarmGpo -PSProvider CitrixGroupPolicy -root \ -controller "localhost"
New-PSDrive -Name ADGpo -PSProvider CitrixGroupPolicy -root \ -domain $GPOName
Export-CtxGroupPolicy -FolderPath $exportpath -DriveName "LocalFarmGpo"
Import-CtxGroupPolicy -FolderPath $exportpath -DriveName "ADGpo" -Verbose

Remove-PSDrive "localfarmgpo" -force
Remove-PSDrive "ADGpo" -force