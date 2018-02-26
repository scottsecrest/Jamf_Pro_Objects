#!/bin/bash

#####################################################################################
#
# Copyright © 2017 Jamf. All rights reserved.
#
#  Redistribution and use in source and binary forms, with or without
#  modification, are permitted provided that the following conditions are met:
#          * Redistributions of source code must retain the above copyright
#            notice, this list of conditions and the following disclaimer.
#          * Redistributions in binary form must reproduce the above copyright
#            notice, this list of conditions and the following disclaimer in the
#            documentation and/or other materials provided with the distribution.
#          * Neither the name of the JAMF Software, LLC nor the
#            names of its contributors may be used to endorse or promote products
#            derived from this software without specific prior written permission.
#
#  THIS SOFTWARE IS PROVIDED BY JAMF SOFTWARE, LLC "AS IS" AND ANY
#  EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
#  WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
#  DISCLAIMED. IN NO EVENT SHALL JAMF SOFTWARE, LLC BE LIABLE FOR ANY
#  DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
#  (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
#  LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
#  ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
#  (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
#  SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
#
#####################################################################################
#
# NAME: jamf_pro_objects.sh and clean_jamf_pro_objects.py
#
# HISTORY: 
#
# Version 1.0 - by Scott Secrest with contributions from Sam Fortuna, Brock Walters and Kyle Bareis
# Version 2.0 - modified by Scott Secrest on 2/22/18 with contributions from Brock Walters
#
#####################################################################################

dunski(){
read -p "Done. ${bold}Press RETURN to continue...${plain}"
}

directory=$(dirname "$0")
objects=(buildings departments categories sites ldapservers userextensionattributes computerextensionattributes directorybindings diskencryptionconfigurations distributionpoints dockitems ibeacons netbootservers packages printers removablemacaddresses scripts softwareupdateservers webhooks networksegments mobiledeviceextensionattributes users usergroups classes advancedusersearches ebooks advancedcomputersearches computergroups computerinvitations licensedsoftware macapplications osxconfigurationprofiles policies restrictedsoftware computers advancedmobiledevicesearches mobiledeviceapplications mobiledeviceconfigurationprofiles mobiledevicegroups mobiledevices)

readme(){

	bold=$(/usr/bin/tput bold)
	plain=$(/usr/bin/tput sgr0)
	printf '\e[8;50;110t'
	/usr/bin/clear
	echo "jamf_pro_objects.sh 2.0 © 2017 jamf

	${bold}Jamf Pro Objects${plain} makes it easy to interact with the Jamf Pro API.
	
	1) ${bold}GET${plain} all XML objects from Jamf Pro
	2) ${bold}CLEAN${plain} local XML objects before ${bold}POST/PUT${plain}
	3) ${bold}POST${plain} all XML object to Jamf Pro
	4) ${bold}EXIT${plain}
	
	Objects are stored at: $directory/
	Logs are stored at: $logfile
"
}

jamfhealthcheck(){

if /usr/bin/curl -ksS "$jamfURL"/healthCheck.html | /usr/bin/grep -q "\\[\\]"
	then
	    echo "Health Check: Passed"
	    loginfo "[Info] $jamfURL Health Check: Passed"
	else
		echo "
${bold}Health Check: FAILED. ${plain}Confirm $jamfURL is avaliable. Exiting...
"
	    logalert "[Alert] $jamfURL Health Check: FAILED"
		exit
fi
}

jamfconfig(){

	echo "Enter the Jamf Pro Server URL:"
	read -r jamfURL
	jamfhealthcheck
	echo "Enter your Jamf Pro Username:"
	read -r apiUser	
	echo "Enter your Jamf Pro Password:"
	read -rs apiPass
}

createfolders(){

if [ ! -d "$directory/JSSResource" ]; then
	echo "Creating folders to store XML Objects at: $directory/"
	mkdir "$directory/JSSResource"
	mkdir -p "$directory/objectID"
 	for object in "${objects[@]}" 
	do
		echo "$directory/$object"
		mkdir -p "$directory/JSSResource/$object"
		clear
	done
fi
}

objectname(){

for file in $directory/objectID/*
do
	indxnum=($(/bin/cat "$file"))
	if [ -z "$getyn" ]
	then
		if ! /bin/cat "$file" | /usr/bin/grep -q "XPath set is empty"
		then
			echo "$(/usr/bin/basename "$file") records: ${#indxnum[@]}" | /usr/bin/awk '{printf "%-37s %-8s %-2s\n",$1,$2,$3}'
		fi
	else
		if ! /bin/cat "$file" | /usr/bin/grep -q "XPath set is empty"
		then
			/usr/bin/basename "$file"
		fi
	fi
done
}

get(){

jamfconfig
loginfo "OPTION: GET $jamfURL"
getid

while true
do
	read -r -p "Save XML Objects from Jamf Pro to $directory/JSSResource (yes / no)? " getyn
	case "$getyn" in
	YES | Yes | Y | yes | y )	getxml
								break			
								;;
	NO | No | N | no | n )		echo
								break
								;;
	* ) 						echo "At the prompt please enter YES or NO:"
								continue
								;;
	esac
done

unset getyn
dunski
readme
return
}

getid(){

echo "A list of database objects & record indexes is being generated..."

for object in "${objects[@]}"
do
	/usr/bin/curl -ksS -H "Accept: application/xml" -u "$apiUser:$apiPass" "$jamfURL/JSSResource/$object" | /usr/bin/xmllint -xpath "//id" - 2>&1 | /usr/bin/sed 's/<[^>]*>/ /g' > "$directory/objectID/$object.xml"
done

echo "The database contains records for the following objects:
"
objectname
echo
}

getxml(){

local total=0
local successful=0
local failures=0

objectrecord=($(objectname))
loginfo "$jamfURL contains records for the following objects:"

for file in "${objectrecord[@]}"
do
	object=$(/usr/bin/basename $file .xml)
	objectindex=($(/bin/cat "$directory/objectID/$file"))
	loginfo "$file: ${objectindex[*]}"
	for id in "${objectindex[@]}"
	do
		/usr/bin/curl -ksS -H "Accept: application/xml" -u "$apiUser:$apiPass" "$jamfURL/JSSResource/$object/id/$id" | xmllint -format - > "$directory/JSSResource/$object/$id.xml"
		result=$(head -c 5 "$directory/JSSResource/$object/$id.xml")
		let total+=1
		if [[ "$result" == "<?xml" ]]; then
			echo "Success: $object/id/$id"
			let successful+=1
		else
			echo "Failure: $object/id/$id"
			let failures+=1
		fi
	done
done

echo "$successful out of $total objects were successfully captured and $failures failed"
}

clean()
{

loginfo "OPTION: CLEAN"

if command -v python3 &>/dev/null; then
    python3 $directory/clean_jamf_pro_objects.py $directory
	echo "The XML has been cleaned"
else
    echo "Python 3 is not installed. Install Python3 and try again."
    logalert "[Failed] Python3 is not installed"
fi

dunski
readme
return
}

post(){

jamfconfig
loginfo "OPTION: POST $jamfURL"

local total=0
local successful=0
local failures=0

	if [ ! -d $directory/JSSResource/ ]; then
		echo "No folder at $directory/.
Use menu option 1 to GET XML objects from Jamf Pro."
		return
	else
	echo "
	Note:
	- Required: Option 2) ${bold}CLEAN${plain} must be run before Option 3) ${bold}POST/PUT${plain}
	- Optional: Object XML can be modified locally before POST/PUT
	- Optional: Create duplicate computer and mobile device objects locally
"

	while true
	do
		read -r -p "${bold}Continue?${plain} (yes / no)? " postyn
		case "$postyn" in
		YES | Yes | Y | yes | y )	break			
									;;
		NO | No | N | no | n )		readme
									continue 2
									;;
		* ) 						echo "At the prompt please enter YES or NO:"
									continue
									;;
		esac
	done
	fi

	for file in $directory/JSSResource/*
	do
		if /usr/bin/find "$file" -mindepth 1 | read -r
		then
		folder+=("$file")
	fi
	done

	for object in "${objects[@]}" 
	do
		for file in $directory/JSSResource/$object/*.xml
		do
			id=$(/usr/bin/basename "${file%.*}")
			name=`/bin/cat $file | /usr/bin/xpath //computer/general/name - 2>&1 | /usr/bin/sed -e 's/\<name>//g; s/\<\/name>//g'`
			statuscode=$(curl -w "%{http_code}\n" -sS -o "/dev/null" -k -X POST -H "Content-Type: application/xml" -u "$apiUser":"$apiPass" "$jamfURL/JSSResource/$object/id/0" -T "$file")
			let total+=1
				if [[ "$statuscode" == "409" ]]; then
					echo "POST [Conflict]: Status Code = $statuscode File = /$object/id/$id.xml"
					loginfo "POST: Status Code = $statuscode /$object/id/$id.xml"
					statuscode=$(curl -w "%{http_code}\n" -sS -o "/dev/null" -k -X PUT -H "Content-Type: application/xml" -u "$apiUser":"$apiPass" "$jamfURL/JSSResource/$object/id/$name" -T "$file")
					loginfo "PUT: Status Code = $statuscode /$object/id/$id.xml"
				fi
				if [[ "$statuscode" == "" ]]; then
					echo "Failed: No object found"
					logalert "POST/PUT [Failed]: Status Code = $statuscode /$object/id/$id.xml"
					let failures+=1
				elif [[ "$statuscode" == "200" ]] || [ "$statuscode" = "201" ]; then
					echo "Post/Put [Success]: Status Code = $statuscode File = /$object/id/$id.xml"
					let successful+=1
				else
					echo "Failed: Status Code = $statuscode File = /$object/id/$id.xml"
					logalert "POST/PUT [Failed]: Status Code = $statuscode /$object/id/$id.xml"
					let failures+=1
				fi
		done
	done
	echo "$successful out of $total objects were successfully POST'ed and $failures failed"

unset postyn
dunski
readme
return
}

delete(){

jamfconfig
loginfo "OPTION: DELETE $jamfURL" 

local total=0
local successful=0
local failures=0

if [ ! -d $directory/objectID ]; then
	echo "No folder at $directory/objectID.
Use menu option 1 to GET XML objects from Jamf Pro."
fi

getid

while true
	do
		read -r -p "${bold}CAUTION!!!${plain} Are you sure you want to ${bold}DELETE${plain} all objects from:
$jamfURL${plain}
(yes / no)? " deleteyn
		case "$deleteyn" in
		YES | Yes | Y | yes | y )	break			
									;;
		NO | No | N | no | n )		readme
									continue 2
									;;
		* ) 						echo "At the prompt please enter YES or NO:"
									continue
									;;
		esac
	done

objectrecord=($(objectname))
loginfo "$directory/objectID/ contains records for the following objects:"

for file in $directory/objectID/*
do
	objectdata=$(head -c 5 "$file")
	if [[ "$objectdata" == "XPath" ]]; then
		continue
	else
		object=$(/usr/bin/basename $file .xml)
		objectindex=($(/bin/cat "$file"))
		loginfo "$file: $objectindex[*]"
		for id in "${objectindex[@]}"
		do	
			result=$(curl -sk -u "$apiUser:$apiPass" "$jamfURL/JSSResource/$object/id/$id" -X DELETE)
			let total+=1
			if [[ "$result" == "<?xml version"* ]]; then
				echo "Success: $object/id/$id"
				let successful+=1
			else
				echo "Failure: $object/id/$id"
				loginfo "DELETE failed: /$object/id/$id.xml"
				loginfo "Result = $result"
				let failures+=1
			fi
		done
	fi
done

echo "$successful out of $total objects were successfully deleted and $failures failed"

unset deleteyn
dunski
readme
return
}

logfile="/private/var/log/jamf_pro_objects.sh.log"
if [ -e "$logfile" ]; then
	/bin/rm -f "$logfile"
fi
/usr/bin/touch "$logfile"
logalert(){
echo "$logtimestamp [ALERT] $1" >> "$logfile"
}
loginfo(){
echo "$logtimestamp  [INFO] $1" >> "$logfile"
}
logstop(){
logalert "$logfile copied to jamf_pro_objects directory..."
echo "$logtimestamp   [END] logging $(/usr/bin/basename "$0")..." >> "$logfile"
/bin/mv -i "$logfile" $directory/"$(/usr/bin/basename "$logfile")"
echo "Copying log file to $directory/
Exiting..."
}
logstart(){
logtimestamp=`date +%Y-%m-%d\ %H:%M:%S`
echo "$logtimestamp [START] logging $(/usr/bin/basename "$0")..." >> "$logfile"
}

displayMenu(){

while true
do
	read -r -p "${bold}OPTION:${plain} " opt
	case "$opt" in
	1 ) get
		;;	
	2 ) clean
		;;	
	3 ) post
		;;
	4 ) logstop
		exit
		;;	
	5 ) delete
		;;
	* ) echo "Please choose an option:${bold}(1, 2, 3, or 4)${plain}"
		continue
		;;
	esac
done
}

createfolders
logstart
readme
displayMenu