#Set Existing Firewall rules for PVS
#Run as admin
#http://www.carlstalhood.com/netscaler-firewall-rules/#pvs

#TFTP
Get-NetFirewallRule -Name "PVSTFTP" | Get-NetFirewallPortFilter | Set-NetFirewallPortFilter -LocalPort 69 -Protocol UDP

#PXE
Get-NetFirewallRule -Name "PVSPXE" | Get-NetFirewallPortFilter | Set-NetFirewallPortFilter –LocalPort (67,4011) -Protocol UDP

#Streaming
Get-NetFirewallRule -Name "PVSSTREAMING" | Get-NetFirewallPortFilter | Set-NetFirewallPortFilter –LocalPort 6910-6930 -Protocol UDP

#BDM
Get-NetFirewallRule -Name "PVSBDM" | Get-NetFirewallPortFilter | Set-NetFirewallPortFilter –LocalPort 6969,2071 -Protocol UDP

#Imaging Wizard to SOAP
Get-NetFirewallRule -Name "PVSSOAP" | Get-NetFirewallPortFilter | Set-NetFirewallPortFilter –LocalPort 54321,54322,54323 -Protocol TCP
