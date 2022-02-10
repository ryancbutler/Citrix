# Auto Download Scripts

PowerShell Scripts that download Citrix media used in a pipeline, Packer job, task sequence, etc.

**NOTE: There are currently no error handling if credentials are mistyped!**

## Get-BinaryExampleNEW.ps1

Uses data from <https://raw.githubusercontent.com/ryancbutler/Citrix_DL_Scrapper/main/ctx_dls.json> to download latest **Multi** and **Single** session VDAs

## GetVDAS.ps1

Example to download multiple VDAs or ISOs using `Get-CTXBinary` function

![Get Binary Dialog](https://github.com/ryancbutler/Citrix/blob/images/images/get-binary.png?raw=true)

## Helpers/Get-CTXBinary.ps1

Function to download ISO or VDA binary.  See **Helpers/Downloads.csv** for mapping

`Get-CTXBinary -DLNUMBER "16834" -DLEXE "Citrix_Virtual_Apps_and_Desktops_7_1912.iso" -CitrixUserName "mycitrixusername" -CitrixPassword "mycitrixpassword" -DLPATH "C:\temp\"`

- Citrix Optimizer <https://support.citrix.com/article/CTX224676>
  - 7-zip is required for the extract process
