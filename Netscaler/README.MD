# Netscaler
Netscaler Scripts and files

## set-nsssl.ps1 
**CREATED: 3-17-16**

Based on this [Citrix blog](https://www.citrix.com/blogs/2015/05/22/scoring-an-a-at-ssllabs-com-with-citrix-netscaler-the-sequel)
- Checks and sets all SSL Netscaler managment, load balancer, Netscaler Gateway and content switch VIPS
- Enables TLS 1.2
- Disables SSLv2 and SSLv3
- Removes "Default" ciphers
- Creates new cipher group and binds to VIPs while removing all other ciphers (auto detects VPX with corresponding supported ciphers)
- Creates and binds Diffie-Hellman (DH) 2048 bit key (Forward Secrecy)
- Creates and binds "Strict Transport Security policy"
- Results in A+ on https://www.ssllabs.com/ssltest
- HTTPS not yet implemented

### Changelog
- 3-17-16: Added port 3008 and 3009 to managment ips
- 3-28-16: Rewrite to reflect PowerShell best practice and managment IP ciphers
- 6-13-16 (Tested with VPX 11.0 65.31)
    - Adjusted ciphers to reflect recent 6-9-16 [Citrix blog](https://www.citrix.com/blogs/2016/06/09/scoring-an-a-at-ssllabs-com-with-citrix-netscaler-2016-update) 
    - Ciphers are now the same for VPX or MPX\SDX
    - Removes management IPS from being adjusted by default.
    - Enables TLS 1.2
