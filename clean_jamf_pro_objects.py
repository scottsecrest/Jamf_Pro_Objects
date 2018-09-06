#!/usr/bin/python

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

import xml.etree.cElementTree as ET
import os
import sys

rootelements = ["site", "category", "computers", "student_ids", "teacher_ids", "student_group_ids", "teacher_group_ids", "mobile_device_group_ids", "scope", "xprotect_version", "expiration_date_utc", "expiration_date_epoch"]
subelements = ["site", "category", "remote_management", "xprotect_version", "self_service_categories", "self_service_icon"]
modifyelements = ["name", "serial_number", "udid", "mac_address", "alt_mac_address", "wifi_mac_address", "bluetooth_mac_address"]
modifysubelements = ["general"]

######################################## DO NOT MODIFY BELOW THIS LINE ############################################

path = sys.argv[1]
files = []
i = 1000

def main():
	
	for rootDir, subDirs, files in os.walk(path):

		for subDir in subDirs:
			if 'objectID' in subDir:
				subDirs.remove(subDir)

		for filename in sorted(files):
			if filename.endswith(".xml"):
				try:
					filepath = (os.path.join(rootDir, filename))
					absfilepath = (os.path.abspath(filepath))
					tree = ET.parse(absfilepath)
					root = tree.getroot()
					print(absfilepath)
				
					for rootelement in rootelements:
							badelement = root.find(rootelement)
							if badelement is not None:
								root.remove(badelement)
								print("Removed tag:", rootelement)

					for child in root:
						for subelement in subelements:
							badelement = child.find(subelement)
							if badelement is not None:
								child.remove(badelement)
								print("Removed tag:", subelement)
					
					if root.tag == "computer" or root.tag == "mobile_device":
						for modifysubelement in modifysubelements:
							generalelement = root.find(modifysubelement)
							if generalelement is not None:
								for modifyelement in modifyelements:
									badelement = generalelement.find(modifyelement)
									if badelement is not None:
										global i
										counter = int(i)
										badelement.text = str(counter)
										print("Changed:", modifyelement, "to", badelement.text)
										i += 1

					tree.write(absfilepath, encoding="UTF-8", xml_declaration=True, short_empty_elements=False)
					
				except ET.ParseError:
					print("Bad File:", absfilepath)
					pass

main ()