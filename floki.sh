#!/bin/bash
#
# floki.sh - Viking recon tool
#
# v0.1 - 04/01/2024
#
# w41l3r

if [ $# -ne 1 ];then
 echo "Syntax: $0 domain_name"
 exit 9
fi

#
# To do's:
#	- function to check/install pre-reqs
#	- some ffuf recon
#
# Pre-reqs:
# 	- amass
#	- assetfinder
#	- subfinder
#	- httpx
#	- whatweb
#	- waybackurls
#	- knockpy
#	- nuclei
#	- nmap
#	- gowitness(*google-chrome is necessary)
#	- fierce
#	- assetfinder's DNS wordlist
#
#!!manually configure subfinder's provider-config.yaml (API Keys)

DOMAIN=$1
WORDLISTS="/opt/tools/wordlists"

#Wordlists
#Assetnote DNS wordlist https://wordlists-cdn.assetnote.io/data/manual/best-dns-wordlist.txt
DNSWORDLIST="${WORDLISTS}/best-dns-wordlist.txt"
#WEBWORDLIST="${WORDLISTS}/common.txt"

mkdir ${DOMAIN}
if [ $? -ne 0 ];then
	echo "\n\\033[31m[!] Failed to create output directory. Bye!\\033[0m"
	exit 1
fi

cd ${DOMAIN}

echo "\n\\033[33m[*] Starting Amass...\\033[0m"
amass enum -passive -norecursive -noalts -d ${DOMAIN} -o amass.txt
echo "\n\\033[33m[*] Starting Assetfinder...\\033[0m"
assetfinder -subs-only ${DOMAIN} | tee assetfinder.txt
echo "\n\\033[33m[*] Starting Subfinder...\\033[0m"
subfinder -d ${DOMAIN} -silent -pc /etc/subfinder/provider-config.yaml |tee subfinder.txt

cat amass.txt assetfinder.txt subfinder.txt | sort -u > subs.txt

#
#!!! Starting some active recon here...
#
if [ ! -s $DNSWORDLIST ];then
	echo "$DNSWORDLIST not found!"
	exit 1
else
	echo "\n\\033[33m[*] Starting Fierce...\\033[0m"
	echo "\\033[33m Relax...you really should go get some coffee...\\033[0m"
	fierce --domain $DOMAIN --traverse 3 --subdomain-file $DNSWORDLIST > fierce.txt
	cat fierce.txt
	if grep "Whoah, it worked" fierce.txt
	then
		"\n\\033[32m Zone transfer has worked!!!...\\033[0m"
		grep "IN" fierce.txt | sed 's/\.$//g' | awk '{print $1}' > zonexfer.txt
		cat zonexfer.txt subs.txt | sort -u > allsubs.txt
		mv subs.txt subs.txt.old
		mv allsubs.txt subs.txt
	fi	
fi
#finished active recon (fierce)

if [ -s subs.txt ];then
	echo "\n\\033[33m[*] Starting waybackurls...\\033[0m"
	cat subs.txt | waybackurls | tee waybackurls.txt
	if [ ! -s waybackurls.txt ];then
		echo "\n\\033[31m[!] No entries found on waybackurls!\\033[0m"
		continue
	fi
	echo "\n\\033[33m[*] Starting httpx...\\033[0m"
	cat waybackurls.txt |grep -v "^$"| httpx --follow-redirects -mc 200,302 | tee httpx.txt
	if [ -s httpx.txt ];then
		cat httpx.txt | cut -f1,2,3 -d'/' | sort -u > unique-httpx.txt
		echo "\n\\033[33m[*] Starting whatweb...\\033[0m"
		whatweb -U=Googlebot -i unique-httpx.txt| tee whatweb.txt
		cat httpx.txt | cut -f3 -d'/' |sort -u > unique-http-subs.txt
		echo "\n\\033[33m[*] Starting gowitness...\\033[0m"
		gowitness file -f unique-http-subs.txt
		echo
		echo "\n\\033[33m[!] Finished Gowitness gathering... run 'gowitness server' on $PWD after floki to see results!!\\033[0m"
		echo
	fi
	echo "\n\\033[33m[*] Starting nuclei...\\033[0m"
	echo "\\033[33m This is REALLY going to take some time... pls be patient!"
	echo
	cat unique-httpx.txt |nuclei -t ~/.local/nuclei-templates/ -fhr |tee nuclei.txt
	echo
	echo "\n\\033[33m[*] Starting nmap...\\033[0m"
	echo
	sudo nmap -n -v -Pn -sS -p- --open -oA ${DOMAIN} -iL subs.txt
else
	echo
	echo "\n\\033[31m[!]No subdomains found!\\033[0m"
	exit 0
fi

exit 0
                                   
