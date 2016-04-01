# Netscaler
Netscaler Scripts and files

## set-nsssl.ps1 3-31-16
Based on this [Citrix blog](https://www.citrix.com/blogs/2015/05/22/scoring-an-a-at-ssllabs-com-with-citrix-netscaler-the-sequel)
- Checks and sets all SSL Netscaler managment, load balancer, Netscaler Gateway and content switch VIPS
- Disables SSLv2 and SSLv3
- Removes "Default" ciphers
- Creates new cipher group and binds to VIPs while removing all other ciphers (auto detects VPX with corresponding supported ciphers)
- Creates and binds Diffie-Hellman (DH) 2048 bit key (Forward Secrecy)
- Creates and binds "Strict Transport Security policy"
- Results in A+ on https://www.ssllabs.com/ssltest
- HTTPS not yet implemented