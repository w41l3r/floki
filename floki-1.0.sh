#!/bin/bash
#
# floki.sh - Viking recon tool
#
# v1.0 10/2024
#
# W41L3R
#
# To do - function to check/install pre-reqs
#
# !!manually configure subfinder's provider-config.yaml (API Keys)

#Your wordlists directory
WORDLISTS="/opt/tools/wordlists"
#
#Assetnote DNS wordlist https://wordlists-cdn.assetnote.io/data/manual/best-dns-wordlist.txt
DNSWORDLIST="${WORDLISTS}/best-dns-wordlist.txt"
#
#Nuclei templates directory
#NUCLEIDIR="/home/w41l3r/.local/nuclei-templates" 
NUCLEIDIR="/opt/tools/projectdiscovery/nuclei-templates" 
#
#Wordlist to be used with ffuf (coming soon...)
#WEBWORDLIST="${WORDLISTS}/common.txt" - will be necessary soon..
#
#Resolvers file to use with puredns
RESOLVERS="/home/w41l3r/.config/puredns/resolvers.txt"
#
#Burp proxy listener to feed (send requests to httpx results)
BURPROXY="http://127.0.0.1:8080"
#
#SecretFinder program
SECRETFINDER="/opt/tools/SecretFinder/SecretFinder.py"

#
# dont change anything after here...
#
DOMAIN=$1


cat `dirname $0`/banner.txt

if [ $# -ne 1 -a $# -ne 2 ];then
 echo
 echo "Syntax: $0 domain_name [-b] [-h]"
 exit 9
fi

function printHelp {
	echo
        echo "Syntax: $0 [-h] [-b] domain.com"
  	echo " -h: Shows this help"
   	echo " -b: Brute force DNS (requires a dns wordlist and a resolvers file. Pls check the DNSWORDLIST and RESOLVERS variables!)"
    	echo "     How to get a resolvers file: dnsvalidator -tL https://public-dns.info/nameservers.txt -threads 20 -o resolvers.txt"
    	echo
     	exit 9
}

BRUTEDNS=0

if [ $# -eq 2 ];then
case $2 in
    "-h")
      printHelp
      ;;
    "-b")
      BRUTEDNS=1
      ;;
    *)
      echo "Invalid option: $2 "
      exit 1
      ;;
esac
fi

#check dependencies/binaries
DEPENDENCIES="amass assetfinder subfinder puredns waybackurls httpx whatweb gowitness nmap nuclei knockpy gau katana uro"

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

#Check if SecretFinder is ok
python3 $SECRETFINDER >/dev/null 2>&1
if [ $? -ne 2 -a $? -ne 0 ];then
	echo "Please install SecretFinder and define the SECRETFINDER variable in the beginning of the script."
 	exit 1
fi

#Check nuclei templates
if [ ! -d $NUCLEIDIR ];then
  	echo -e "\n\\033[31m[*] No nuclei templates found! Check NUCLEIDIR variable. Bye!\\033[0m"
  	exit 1
fi

if [ -d ${DOMAIN} ];then
	BACKUPDIR="${DOMAIN}-`date +%d%b%H%M`.bkp"
	echo -e "\n\\033[33m[*] Output directory already exists... Renaming it to ${BACKUPDIR} \\033[0m"
 	rm -rf ${BACKUPDIR} 2>/dev/null
  	mv ${DOMAIN} ${BACKUPDIR} 
   	if [ $? -ne 0 ];then
    		echo -e "\n\\033[31m[*] Error renaming output dir ${DOMAIN}. Bye!\\033[0m"
      		exit 1
      	fi
fi

REVELIO="`dirname $0`/revelio.sh"
if [ ! -s $REVELIO ];then
	echo
	echo -e "\n\\033[33m[!] revelio.sh is missing. Check it out! Exiting...\\033[0m"
	echo
	exit 1
fi

$REVELIO $DOMAIN

cat *-subs.txt |grep -v "^$" > subs.txt

if [ -s subs.txt ];then #successfully gathered subdomains
	WAYBACKURLSFOUND=0
 	GAUFOUND=0
	#
	# KNOCKPY
	#
	echo -e "\n\\033[33m[*] Starting knockpy...\\033[0m"
	for CURDOMAIN in `cat domainsList-*.txt`
	do
		if [ -s "${CURDOMAIN}-onlysubs.txt" ];then
  			knockpy --user-agent Googlebot -w "./${CURDOMAIN}-onlysubs.txt" $CURDOMAIN | tee -a ${CURDOMAIN}-knockpy.txt
		fi
	done
	echo -e "\n\\033[33m[*] Starting waybackurls...\\033[0m"
	#
	# WAYBACKURLS
	#
	cat subs.txt | waybackurls | tee waybackurls.txt
	if [ ! -s waybackurls.txt ];then
		echo -e "\n\\033[31m[*] No entries found on waybackurls!\\033[0m"
  	else
   		WAYBACKURLSFOUND=1
	fi
 	cat subs.txt | gau | tee gau.txt
  	if [ ! -s gau.txt ];then
		echo -e "\n\\033[31m[*] No entries found by gau!\\033[0m"
  	else
   		GAUFOUND=1
	fi
 	if [ $WAYBACKURLSFOUND -eq 0 -a $GAUFOUND -eq 0 ];then
  		continue
    	fi

	#
	# HTTPX
	#
	echo -e "\n\\033[33m[*] Starting httpx...\\033[0m"
	grep -h -i '^http' waybackurls.txt gau.txt 2>/dev/null | sort -u | httpx --follow-redirects -mc 200,302 | tee httpx.txt
	if [ -s httpx.txt ];then
 		echo -e "\n\\033[33m[*] Starting crawling...\\033[0m"
 		cat httpx.txt | katana -jc >> enpoints.txt
   		cat enpoints.txt | uro >> final-endpoints.txt
		cat final-endpoints.txt | cut -f1,2,3 -d'/' | sort -u > unique-httpx.txt
		echo -e "\n\\033[33m[*] Starting whatweb...\\033[0m"
		whatweb -U=Googlebot -i unique-httpx.txt| tee whatweb.txt
		cat httpx.txt | cut -f3 -d'/' |sort -u > unique-http-subs.txt
  		echo -e "\n\\033[33m[*] Starting SecretFinder...this will take a while...\\033[0m"
    		sleep 1
    		grep '\.js$' final-endpoints.txt|uniq|sort|while read thisurl
      		do
			python3 $SECRETFINDER -i $thisurl -o cli | tee -a secretfinder.txt
 		done
		echo -e "\n\\033[33m[*] Starting gowitness...\\033[0m"
		gowitness file -f unique-http-subs.txt
		echo
		echo -e "\n\\033[33m[*] Finished Gowitness gathering... run 'gowitness server' on $PWD after floki to see results!!\\033[0m"
		echo
	fi

	#
 	# NUCLEI
	#
 	echo -e "\n\\033[33m[*] Starting nuclei...\\033[0m"
        echo -e "\\033[33m This is REALLY going to take some time... pls be patient!"
	echo
	cat final-endpoints.txt |nuclei -t $NUCLEIDIR -fhr |tee nuclei.txt

 	#Send requests to Burp
  	echo -e "\n\\033[33m[*] Im going to feed your Burp. Please check if $BURPROXY is listening...\\033[0m"
   	echo -n -e "\n\\033[33m[*] May i start sending requests to burp(Y|n)? \\033[0m"
    	read RESP
     	case $RESP in
        y|Y)
		curl -s -v -k $BURPROXY | grep -i burp >/dev/null
  		if [ $? -eq 0 ];then
    			cat httpx.txt | awk '{print $1}' | while read linha 
			do                 
				curl --proxy $BURPROXY -s -k $linha
			done
   		else
     			echo -e "\n\\033[31mError comunicating with BURP.\\033[0m"
			
    		fi
      
	;;
 	*)
		echo "ok, no Burp then..."
  	;;
   	esac
 
else #no subs found
	echo
	echo -e "\n\\033[31m[*]No subdomains found!\\033[0m"
	exit 5
fi

exit 0
