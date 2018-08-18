# Introduction (Deprecated)
Scripts the tweak Citrix Storefront 2.6 for faster load time.

## SFTweaks.ps1
Connects to all Storefront servers in a cluster:
- Disables signature checking in .NET
- Enables pool sockets in storefront
- Disables Netbios

## SFApplicationInitialization.ps1
Configures Storefront and IIS for application-initialization (**Windows 2008R2 Only**)
Must be run as administrator and application-initialization must be already installed (see http://support.citrix.com/article/CTX137400)
