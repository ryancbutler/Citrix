# Auto Download Scripts
PowerShell Scripts that download Citrix media used in a pipeline, Packer job, task sequence, etc.

**NOTE: There are currently no error handling if credentials are mistyped!**

## GetVDAS.ps1
Example to download multiple VDAs or ISOs using `Get-CTXBinary` function

![Get Binary Dialog](https://github.com/ryancbutler/Citrix/blob/images/images/get-binary.png?raw=true)

## Helpers/Get-CTXBinary.ps1
Function to download ISO or VDA binary.  See **Helpers/Downloads.csv** for mapping

`Get-CTXBinary -DLNUMBER "16834" -DLEXE "Citrix_Virtual_Apps_and_Desktops_7_1912.iso" -CitrixUserName "mycitrixusername" -CitrixPassword "mycitrixpassword" -DLPATH "C:\temp\"`

## Currently Works with
| DL Number | Download |
| --- | --- |
|16834|Citrix_Virtual_Apps_and_Desktops_7_1912.iso|
|16837|VDAServerSetup_1912.exe|
|16838|VDAWorkstationSetup_1912.exe|
|16839|VDAWorkstationCoreSetup_1912.exe|
|16555|Citrix_Virtual_Apps_and_Desktops_7_1909.iso|
|16558|VDAServerSetup_1909.exe|
|16559|VDAWorkstationSetup_1909.exe|
|16560|VDAWorkstationCoreSetup_1909.exe|
|16107|Citrix_Virtual_Apps_and_Desktops_7_1906.iso|
|16110|VDAServerSetup_1906.exe|
|16111|VDAWorkstationSetup_1906.exe|
|16112|VDAWorkstationCoreSetup_1906.exe|
|15901|VDAServerSetup_1903.exe|
|15902|VDAWorkstationSetup_1903.exe|
|15903|VDAWorkstationCoreSetup_1903.exe|

- Citrix Optimizer https://support.citrix.com/article/CTX224676
  - 7-zip is required for the extract process