# Netscaler
Netscaler Scripts and files

## SetNetscalerSSLOptions.ps1 2-21-16
Based on this [Citrix blog](https://www.citrix.com/blogs/2015/05/22/scoring-an-a-at-ssllabs-com-with-citrix-netscaler-the-sequel)
- Disables SSLv2 and SSLv3
- Removes "Default" ciphers
- Creates new cipher group and binds to VIPs (auto detects VPX and adjusts cipher groups)
- Checks all SSL load balancer, Netscaler Gateway and content switch VIPS
- Creates and binds Strict Transport Security policy to all VIPs
- Results in A+ on https://www.ssllabs.com/ssltest
