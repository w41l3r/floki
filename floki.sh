#!/bin/bash

#
# FLOKI - the seas of Web Recon automator
#
# by w41l3r

VERSION='0.2'
DEPS="assetfinder wafw00f whatweb"
HTTPROBE="httprobe"
REPORT="floki-report-`date +%d%m%y%H%M`.html"


function printBanner()
{
echo 
echo '.-::::: :::         ...      :::  .   :::'
echo ";;;'''' ;;;      .;;;;;;;.   ;;; .;;,.;;;"
echo "[[[,,== [[[     ,[[     \[[, [[[[[/'  [[["
echo '`$$$"`` $$"     $$$,     $$$_$$$$,    $$$'
echo ' 888   o88oo,.__"888,_ _,88P"888"88o, 888'
echo ' "MM,  """"YUMMM  "YMMMMMP"  MMM "MMP"MMM'
echo 
echo ' `--- sailing the seas of Reconnaissance'
echo
echo " Version: $VERSION"
echo

}

function tryInstall()
{
	echo "Package $1 not found. Installing..."
	sudo apt install $1 -y
	if [ $? -ne 0 ];then
		echo
		echo "[-] Errors installing $1"
		echo "[!] Please install $1 before using Loki!"
		echo "[!] Exiting..."
		cd ..
		exit 1
	fi
}

function printHelp()
{
echo
echo "Syntax: $0 domain_name"
echo " Example: $0 evilcorp.com"
echo
}

function generateReport()
{
	WEBURLS=$2
	WAFW00FOUT=$3
	WHATWEBOUT=$4
	echo "<HTML><HEAD><TITLE>Floki Report for $1 </TITLE></HEAD><BODY><BR>" > $REPORT
	echo "<H1> Floki Report for $1 generated at `date +%d/%b/%y_%H:%M` </H1>" >> $REPORT
	echo "<P>" >> $REPORT
	cat $WEBURLS |while read nexturl
	do
		echo "<H2> $nexturl </H2>" >> $REPORT
		SUB=`echo $nexturl |cut -f3 -d'/'`
		ls -1 *${SUB}*.png | awk -F : '{ print $1":\n<BR><IMG SRC=\""$1""$2"\" width=600><BR>"}' >> $REPORT
		echo "<H3> WAF check-up </H3>" >> $REPORT
		echo "<PRE>" >> $REPORT
		grep -A1 $nexturl $WAFW00FOUT >> $REPORT
		echo "</PRE>" >> $REPORT
		echo "<BR/>" >> $REPORT
		echo "<H3> WebServer technologies </H3>" >> $REPORT
		echo "<PRE>" >> $REPORT
		cat whatweb/whatweb-$SUB.txt >> $REPORT
		echo "</PRE>" >> $REPORT
		grep $nexturl $WHATWEBOUT >> $REPORT
	done
	echo "</P></BODY></HTML>" >> $REPORT
}

function zoneTransfer()
{
	DOMAIN=$1
	SUBSFILE=$2
	TEMPFILE="subs_`date +%d%m%y%H%M%S`.tmp"

	host -t NS $DOMAIN |awk '{print $4}'|sed 's/\.$//'|while read namesrv
	do
		echo
		echo -n -e "\e[1;31m [+] Trying zone-transfer using $namesrv ... \e[0m"
		echo
		host -l $DOMAIN $namesrv > zonetransfer.out 2>/dev/null
		if [ $? -ne 0 ]
		then
			echo " denied!"
			sleep 3
		else
			echo
			echo -n -e "\e[1;31m [+] Whoohaaaa! Zone Transfer worked!!! Take a look... \e[0m"
			echo
			cat zonetransfer.out
			cat zonetransfer.out |grep "has address"| awk '{print $1}' |tee -a $SUBSFILE
			cat $SUBSFILE |sed 's/\.$//' |sort -u > $TEMPFILE && mv $TEMPFILE $SUBSFILE
			echo
			echo -n -e "\e[1;31m [+] Take a look at our brand new subdomains found! \e[0m"
			echo
			cat $SUBSFILE
			touch zonexfer.tmp
		fi
	done
}

function reverseLookup()
{
	SUBSFILE=$1
	DOMAIN=$2
	AUX='subdomains.aux'
	TEMPFILE="subs_`date +%d%m%y%H%M%S`.tmp"
	> $TEMPFILE

	cat $SUBSFILE |while read subdomain
	do
		host $subdomain >> $TEMPFILE
	done
	MOSTRANGE="`cat $TEMPFILE |awk '{print $4}'|cut -f 1,2,3 -d'.' |sort |uniq -c|sort -n |tail -1 |awk '{print $2}'`"
	echo "Most used ip network is ${MOSTRANGE}.0 . We will use this (/24), but i encourage you to consider the others later..."
	echo "I'll put some multi-range option for you here some day :)"

	echo "Let's do some reverse DNS resolution. This can take a while... Relax..."
	for ip in $(seq 2 254); do
		host ${MOSTRANGE}.${ip} |grep -i $DOMAIN |grep -v "not found"|tee -a $AUX
	done

	echo
	echo -e "\e[1;31m [+] I've found these subdomains using reverse DNS lookup. Should we keep them? \e[0m"
	echo -n -e "\e[1;31m Please choose [Y/n] \e[0m"
	read RESP
	case $RESP in
		y|Y) echo "Merging the subdomains findings..."
		     cat $AUX |awk '{print $5}' >> $SUBSFILE
		     cat $SUBSFILE |sort -u |grep -v '\.$' > $TEMPFILE && mv $TEMPFILE $SUBSFILE && rm -f $AUX 
		     echo
		     echo -e "\e[1;31m [+] New list of subdomains found: \e[0m"
		     echo
		     cat $SUBSFILE
		;;
		*) echo "Dropping the subdomains..."; rm -f $AUX;;
	esac
	echo

}

printBanner


for PKG in $DEPS
do
	which $PKG >/dev/null || tryInstall $PKG
done

which httprobe >/dev/null 
if [ $? -ne 0 ];
then
	echo "Httprobe not found. Trying to install..."
	go get -u github.com/tomnomnom/httprobe
	if [ $? -ne 0 ];then
		echo "Problems installing httprobe!"
		echo "Please install it manually to use Floki."
		echo "Bye!"
		cd ..
		exit 1
	fi
fi

if [ $# -ne 1 ];then
	printHelp
	exit 1
fi

if ! host $1 >/dev/null 2>/dev/null
then
	echo "[-] Is this domain correct?"
	echo "[!] Think, and come back later..."
	exit 1
fi

echo
echo -e "\e[1;31m [+] All ready! let's look for some subdomains now... \e[0m"
echo

if [ -d $1 ]
then
	tar czvf "backup_${1}_`date +%d%m%y%H%M`.tar.gz" $1 && rm -rf $1
	if [ $? -ne 0 ];then
		echo
		echo -e "\e[1;31m [FATAL!] The $1 directory exists, but we couldn't archive it. (Please, check permissions and disk space.) \e[0m"
	        echo -e "\e[1;31m [!] Abandon the ship! \e[0m"
		echo
		exit 1
	fi
fi

mkdir $1
if [ $? -ne 0 ]; then
	echo
	echo -e "\e[1;31m [FATAL!] We don't have permission to write here or disk is full! \e[0m"
	echo -e "\e[1;31m [!] Abandon the ship! \e[0m"
	echo
	exit 1
fi

cd $1

SUBS="subs-${1}.txt"
WEBURLS="web-${1}.txt"
WHATWEBOUT="whatweb-${1}.txt"
WAFW00FOUT="wafw00f-${1}.txt"

zoneTransfer $1 $SUBS
if [ ! -f zonexfer.tmp ]; then

	#only try to find subdomains if zoneTransfer isn't working

	echo $1 |assetfinder --subs-only |tee $SUBS

	echo
	echo -e "\e[1;31m [+] Some reverse lookup to find more subdomains... \e[0m"
	echo

	reverseLookup $SUBS $1
fi

echo
echo -e "\e[1;31m [+] Hey, take a look at their Websites! \e[0m"
echo

cat $SUBS |sort -u | httprobe -c 50 -prefer-https |tee $WEBURLS
cat $WEBURLS |sort -u > /tmp/floki.tmp
mv /tmp/floki.tmp $WEBURLS

echo
echo -e "\e[1;31m [+] What web? \e[0m"
echo

if [ ! -d ./whatweb ];then
	mkdir whatweb 
	if [ $? -ne 0 ]; then 
		echo "[!] Problems creating the whatweb directory."; cd .. ; exit 1
	fi
fi
cat $WEBURLS |sort -u |while read weburl; do
 OUTFILE=whatweb-`echo $weburl|cut -f3 -d'/'`.txt
 whatweb --log-verbose=whatweb/$OUTFILE $weburl |tee $WHATWEBOUT
done

echo
echo -e "\e[1;31m [+] Do they use WAF? \e[0m"
echo

wafw00f -i $WEBURLS |grep -e 'Checking' -e 'is behind' -e 'No WAF detected' |tee $WAFW00FOUT

echo
echo -e "\e[1;31m [+] ok, now i'll get some screenshots for you... \e[0m"
echo
cat $WEBURLS |while read line; do 
	NAMEOUT=`echo $line |cut -f3 -d'/'`
	rm -f ${NAMEOUT}.png
	cutycapt --url=${line} --out=${NAMEOUT}.png --insecure
	if [ $? -ne 0 ];then
		echo -e "\e[1;31m [!] ERRORs getting the screenshot of ${line} \e[0m"
	fi
done

echo
echo -e "\e[1;31m [+] Generating Report... \e[0m"
echo 
generateReport $1 $WEBURLS $WAFW00FOUT $WHATWEBOUT

echo
echo -e "\e[1;31m [+] Report $REPORT generated sucessfully! \e[0m"
echo 

echo
echo -e "\e[1;31m [+] Everything done here. Happy h4ck1ng! \e[0m"
echo 

firefox $REPORT
rm -f zonexfer.tmp 2>/dev/null
cd ..
exit 0

