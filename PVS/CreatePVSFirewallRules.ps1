#Creates firewall rules for PVS
#Run as admin
#http://www.carlstalhood.com/netscaler-firewall-rules/#pvs

#TFTP
New-NetFirewallRule -DisplayName "Citrix PVS TFTP" -Name "PVSTFTP" -Group "Citrix Provisioning Services" -Direction Inbound –LocalPort 69 -Protocol UDP -Action Allow

#PXE
New-NetFirewallRule -DisplayName "Citrix PVS PXE" -Name "PVSPXE" -Group "Citrix Provisioning Services" -Direction Inbound –LocalPort (67,4011) -Protocol UDP -Action Allow

#Streaming
New-NetFirewallRule -DisplayName "Citrix PVS Streaming" -Name "PVSSTREAMING" -Group "Citrix Provisioning Services" -Direction Inbound –LocalPort 6910-6930 -Protocol UDP -Action Allow

#BDM
New-NetFirewallRule -DisplayName "Citrix PVS BDM" -Name "PVSBDM" -Group "Citrix Provisioning Services" -Direction Inbound –LocalPort 6969,2071 -Protocol UDP -Action Allow

#Imaging Wizard to SOAP
New-NetFirewallRule -DisplayName "Citrix PVS SOAP" -Name "PVSSOAP" -Group "Citrix Provisioning Services" -Direction Inbound –LocalPort 54321,54322,54323 -Protocol TCP -Action Allow
