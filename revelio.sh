#!/bin/bash

if [ -z $1 ];then
 echo -n "Informe o dominio principal: "
 read MAINDOMAIN
else
 MAINDOMAIN=$1
fi

WHOISXML_TEMPLATE="/opt/tools/floki/rev-whois.req"
SECTRAILS_API='xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx'
DOMAINSLIST="domainsList-`date +%d%m%y%H%M%S`.txt"
OWNER_NAME=`whois $MAINDOMAIN | grep owner: | awk '{for (i=2; i<=NF; i++) printf " %s", $i; print ""}'|cut -f2- -d' '`

if [ -d $MAINDOMAIN ]; then
        echo -e "\n\\033[33m[*] Output directory already exists... Renaming it to ${MAINDOMAIN}.old \\033[0m"
	#echo "Renomeando a pasta $MAINDOMAIN para ${MAINDOMAIN}.old"
	mv $MAINDOMAIN ${MAINDOMAIN}.old
fi

mkdir $MAINDOMAIN
cd $MAINDOMAIN

echo
echo -e "\n\\033[33mCompany Name: $OWNER_NAME \\033[0m"
#echo "Nome da empresa: $OWNER_NAME"
echo
echo -n -e "\n\\033[33mContinue with this value?(y/N) \\033[0m"
#echo -n "Deseja continuar com este valor?(s/N) "
read RESP

case $RESP in
y|Y)
	REQFILE="rev-whois-${MAINDOMAIN}.req"
	if [ ! -s $WHOISXML_TEMPLATE ];then
	        echo -e "\n\\033[33m[*] Whoisxmlapi template file not found! Exiting... \\033[0m"
		exit 1
	fi
	cat $WHOISXML_TEMPLATE | sed "s/OWNER_NAME/$OWNER_NAME/g" > $REQFILE
	echo
	echo -e "\n\\033[33mConsulting whoisxmlapi. Please wait... \\033[0m"
	curl -s -X POST -H "Content-Type: application/json" -d @$REQFILE https://reverse-whois.whoisxmlapi.com/api/v2 | jq -r '.domainsList[]' > $DOMAINSLIST
	echo
        echo -e "\n\\033[33m[*] DomainsList file ${DOMAINSLIST} generated. \\033[0m"
	echo
	cat $DOMAINSLIST | while read CURDOMAIN
	do
		ZONEXFER=0
		echo -e "\n\\033[33m[*] Trying Zone Xfer... \\033[0m"
		for server in $(host -t ns ${CURDOMAIN} | cut -d " " -f4)
		do
        		host -l ${DOMAIN} ${server}
        		if [ $? -ne 0 ];then
                		echo -e "\n\\033[31m[*] Zone transfer has failed!\\033[0m"
        		else
                		echo -e "\n\\033[32m YESS!!! it worked!!!\\033[0m"
                		host -l ${CURDOMAIN} ${server} |tee ${CURDOMAIN}-zonexfer.txt
                		grep "has address" ${CURDOMAIN}-zonexfer.txt |awk '{print $1}' > ${CURDOMAIN}-subs-transfered.txt
				cp ${CURDOMAIN}-subs-transfered.txt ${CURDOMAIN}-subs.txt
				cat ${CURDOMAIN}-subs.txt | sed "s/.${CURDOMAIN}$//g" > ${CURDOMAIN}-onlysubs.txt
                		ZONEXFER=1
       			fi
		done

		if [ $ZONEXFER -eq 0 ];then
			SUBDOMAINSLIST=${CURDOMAIN}-subs.txt
			ONLYSUBS=${CURDOMAIN}-onlysubs.txt
			echo -e "\n\\033[33mLooking for $CURDOMAIN subdomains on SecurityTrails. Please wait... \\033[0m"
			curl -s --request GET --url "https://api.securitytrails.com/v1/domain/$CURDOMAIN/subdomains?children_only=false&include_inactive=true" --header 'accept: application/json' --header "APIKEY: $SECTRAILS_API" | jq -r '.subdomains[]' > $ONLYSUBS
			cat $ONLYSUBS | while read linha
			do
				echo ${linha}.${CURDOMAIN} >> ${SUBDOMAINSLIST}
			done
			echo
			echo -e "\n\\033[33m[*] $SUBDOMAINSLIST file generated. \\033[0m"
			echo
		fi
	done
	echo
	echo bye.
;;
*)
	echo "Saindo..."
	exit 0
;;
esac

