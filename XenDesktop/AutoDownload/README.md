# Auto Download Scripts
PowerShell Scripts that download Citrix media used in a pipeline, Packer job, task sequence, etc.  

**NOTE: By default script(s) prompts for credenitals but can be changed. If needed, please take caution in storing password! Not recommened to store in plaintext!**

**NOTE: There are currently no error handling if credentials are mistyped!**

## Currently Works with
- Citrix Optimizer https://support.citrix.com/article/CTX224676
  - 7-zip is required for the extract process
- Citrix CVAD Server VDA 1906
- Citrix CVAD Desktop VDA 1906
- Citrix CVAD Server VDA 7.15 CU 4 (LTSR)
- Citrix CVAD Desktop VDA 7.15 CU 4 (LTSR)