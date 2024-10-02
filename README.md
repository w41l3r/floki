# floki.sh - Viking recon tool

 v1.0 - 10/2024

 w41l3r

 To do - function to check/install pre-reqs

# Pre-reqs:
- revelio [https://github.com/w41l3r/revelio]
- amass [https://github.com/owasp-amass/amass]
- assetfinder [https://github.com/tomnomnom/assetfinder]
- subfinder [https://github.com/projectdiscovery/subfinder]
- httpx [https://github.com/projectdiscovery/httpx]
- whatweb [https://github.com/urbanadventurer/WhatWeb]
- waybackurls [https://github.com/tomnomnom/waybackurls]
- knockpy [https://github.com/guelfoweb/knock]
- nuclei [https://github.com/projectdiscovery/nuclei]
- mantra [https://github.com/MrEmpy/mantra]
- nmap [https://nmap.org/download]
- gowitness(*google-chrome is necessary) [https://github.com/sensepost/gowitness]
- puredns [https://github.com/d3mondev/puredns]
- gau [https://github.com/lc/gau]
- assetnote's DNS wordlist [https://wordlists-cdn.assetnote.io/data/manual/best-dns-wordlist.txt]

# !!manually configure subfinder's provider-config.yaml (API Keys)
# !!!remember to configure sudoers to NOPASSWD to run nmap without asking password

Syntax: ./floki.sh domain_name

 Example: ./floki.sh evilcorp.com
