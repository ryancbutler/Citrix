# Netscaler
Netscaler Scripts and files

## SetNetscalerSSLOptions.ps1
Based on this [Citrix blog](https://www.citrix.com/blogs/2015/05/22/scoring-an-a-at-ssllabs-com-with-citrix-netscaler-the-sequel)
- Disables SSLv2 and SSLv3
- Removes "Default" ciphers
- Creates new cipher group and binds to VIPs
- Checks all load balancer, Netscaler Gateway and content switch VIPS
- Creates and binds Strict Transport Security policy to all VIPs
- Results in A+ on https://www.ssllabs.com/ssltest
