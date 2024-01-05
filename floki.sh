#!/bin/bash
#
# floki.sh - Viking recon tool
#
# v0.5 - 04/01/2024
#
# W41L3R
#
# To do - function to check/install pre-reqs
#
# Pre-reqs:
# 	- amass [https://github.com/owasp-amass/amass]
#	- assetfinder [https://github.com/tomnomnom/assetfinder]
#	- subfinder [https://github.com/projectdiscovery/subfinder]
#	- httpx [https://github.com/projectdiscovery/httpx]
#	- whatweb [https://github.com/urbanadventurer/WhatWeb]
#	- waybackurls [https://github.com/tomnomnom/waybackurls]
#	- knockpy [https://github.com/guelfoweb/knock]
#	- nuclei [https://github.com/projectdiscovery/nuclei]
#	- mantra [https://github.com/MrEmpy/mantra]
#	- nmap [https://nmap.org/download]
#	- gowitness(*google-chrome is necessary) [https://github.com/sensepost/gowitness]
#	- fierce [https://github.com/mschwager/fierce]
#	- assetnote's DNS wordlist [https://wordlists-cdn.assetnote.io/data/manual/best-dns-wordlist.txt]
#
# !!manually configure subfinder's provider-config.yaml (API Keys)
# !!!remember to configure sudoers to NOPASSWD to run nmap without asking password

DOMAIN=$1
DEPENDENCIES="amass assetfinder subfinder fierce mantra waybackurls httpx whatweb gowitness nmap nuclei"
WORDLISTS="/opt/tools/wordlists"
#Wordlists
#Assetnote DNS wordlist https://wordlists-cdn.assetnote.io/data/manual/best-dns-wordlist.txt
DNSWORDLIST="${WORDLISTS}/best-dns-wordlist.txt"
#WEBWORDLIST="${WORDLISTS}/common.txt"

#
# dont change anything after here...
#
cat `dirname $0`/banner.txt

if [ $# -ne 1 ];then
 echo
 echo "Syntax: $0 domain_name"
 exit 9
fi

#check dependencies/binaries
function check_deps {
	which $1 >/dev/null
 	if [ $? -ne 0 ];then
  		echo -e "\n\\033[31m$1 is missing! Please install it and put it on PATH.\\033[0m"
    		exit 1
      	fi
}

for DEP in $DEPENDENCIES
do
	check_deps $DEP
done

mkdir ${DOMAIN}
if [ $? -ne 0 ];then
	echo -e "\n\\033[31m[*] Failed to create output directory. Bye!\\033[0m"
	exit 1
fi

cd ${DOMAIN}

echo -e "\n\\033[33m[*] Starting Amass...\\033[0m"
#amass enum -passive -norecursive -noalts -d ${DOMAIN} -o amass.txt
amass enum -passive -norecursive -d ${DOMAIN} -o amass.txt
echo -e "\n\\033[33m[*] Starting Assetfinder...\\033[0m"
assetfinder -subs-only ${DOMAIN} | tee assetfinder.txt
echo -e "\n\\033[33m[*] Starting Subfinder...\\033[0m"
subfinder -d ${DOMAIN} -silent -pc /etc/subfinder/provider-config.yaml |tee subfinder.txt

cat amass.txt assetfinder.txt subfinder.txt | sort -u > subs.txt

#
#!!! Starting some active recon here...
#
FIERCEFLAG=1
if [ ! -s $DNSWORDLIST ];then
	echo -e "\n\\033[31m$DNSWORDLIST empty or inexistent!"
	echo -e "Trying to get it...\\033[0m"
	wget https://wordlists-cdn.assetnote.io/data/manual/best-dns-wordlist.txt -O $DNSWORDLIST
	if [ $? -ne 0 ];then
		echo -e "\n\\033[31mError downloading the DNS wordlist. Wont use fierce!\\033[0m"
		FIERCEFLAG=0
	fi
fi
if [ $FIERCEFLAG -eq 1 ];then
	echo -e "\n\\033[33m[*] Starting Fierce...\\033[0m"
	echo -e "\\033[33m Relax...you really should go get some coffee...\\033[0m"
	fierce --domain $DOMAIN --traverse 3 --subdomain-file $DNSWORDLIST > fierce.txt
	cat fierce.txt
	if grep "Whoah, it worked" fierce.txt
	then
		echo -e "\n\\033[32m Zone transfer has worked!!!...\\033[0m"
		grep "IN" fierce.txt | sed 's/\.$//g' | awk '{echo -e $1}' > zonexfer.txt
		cat zonexfer.txt subs.txt | sort -u > allsubs.txt
		mv subs.txt subs.txt.old
		mv allsubs.txt subs.txt
  	else
   		grep -i found fierce.txt | awk '{print $2}'|sed 's/\.$//' > subs-fierce.txt
     		cat subs-fierce.txt subs.txt | sort -u > allsubs.txt
       		mv allsubs.txt subs.txt
	fi	
fi

#finished active recon (fierce)

if [ -s subs.txt ];then
	echo -e "\n\\033[33m[*] Starting waybackurls...\\033[0m"
	cat subs.txt | waybackurls | tee waybackurls.txt
	if [ ! -s waybackurls.txt ];then
		echo -e "\n\\033[31m[*] No entries found on waybackurls!\\033[0m"
		continue
	fi
	echo -e "\n\\033[33m[*] Starting httpx...\\033[0m"
	cat waybackurls.txt |grep -v "^$"| httpx --follow-redirects -mc 200,302 | tee httpx.txt
	if [ -s httpx.txt ];then
		cat httpx.txt | cut -f1,2,3 -d'/' | sort -u > unique-httpx.txt
		echo -e "\n\\033[33m[*] Starting whatweb...\\033[0m"
		whatweb -U=Googlebot -i unique-httpx.txt| tee whatweb.txt
		cat httpx.txt | cut -f3 -d'/' |sort -u > unique-http-subs.txt
  		echo -e "\n\\033[33m[*] Starting mantra...\\033[0m"
    		grep '\.js$' httpx.txt | mantra -s -ua Googlebot
		echo -e "\n\\033[33m[*] Starting gowitness...\\033[0m"
		gowitness file -f unique-http-subs.txt
		echo
		echo -e "\n\\033[33m[*] Finished Gowitness gathering... run 'gowitness server' on $PWD after floki to see results!!\\033[0m"
		echo
	fi
	echo -e "\n\\033[33m[*] Starting nuclei...\\033[0m"
        RUNNUCLEI=1
 	if [ -d ~/.local/nuclei-templates ];then
  		NUCLEIDIR="~/.local/nuclei-templates"
    	elif [ -d ~/nuclei-templates ];then
     		NUCLEIDIR="~/nuclei-templates"
        else
		echo -e "\n\\033[31m[*] No nuclei templates found!\\033[0m"
  		RUNNUCLEI=0
        fi
	if [ $RUNNUCLEI -eq 1 ];then
		echo -e "\\033[33m This is REALLY going to take some time... pls be patient!"
		echo
		cat unique-httpx.txt |nuclei -t $NUCLEIDIR -fhr |tee nuclei.txt
		echo
        else
		echo "Skipping nuclei (didnt find templates dir...)"
        fi
	echo -e "\n\\033[33m[*] Starting nmap...\\033[0m"
	echo
	sudo nmap -n -v -Pn -sS -p- --open -oA ${DOMAIN} -iL subs.txt
else
	echo
	echo -e "\n\\033[31m[*]No subdomains found!\\033[0m"
	exit 0
fi

exit 0
