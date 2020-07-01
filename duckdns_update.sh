#!/bin/bash

# The content of this file are licensed under the MIT License (https://opensource.org/licenses/MIT)
# MIT License
#
# Copyright (c) 2020 Paul Moss
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.
#
# Script to update one or more ip address with the free service duckdns.org
# Created by Paul Moss
# Created: 2020-06-19
# Updated: 2020-06-24
# File Name: duckdns_update.sh
# Github: https://github.com/Amourspirit/duckdns_script
# Version 1.0.5

TOKEN_FILE="$HOME/.duckdns/token"
IP=0
LOG_PATH="$HOME/.duckdns/log"
mkdir -p "$LOG_PATH"
IP_LOGFILE="$LOG_PATH/ip.log"
OLD_IP_LOGFILE="$LOG_PATH/ip_old.log"
RESULT_LOGFILE="$LOG_PATH/duckdns.log"
DOMAINS="$HOME/.duckdns/domains.txt"
TMP_FILE='/tmp/current_ip_address'
# Age in minutes to keep ipaddress store in tmp file
MAX_IP_AGE=5

# function: _trim
# Param 1: the variable to trim whitespace from
# Usage:
#   while read line; do
#       if [[ "$line" =~ ^[^#]*= ]]; then
#           setting_name=$(_trim "${line%%=*}");
#           setting_value=$(_trim "${line#*=}");
#           SCRIPT_CONF[$setting_name]=$setting_value
#       fi
#   done < "$TMP_CONFIG_COMMON_FILE"
function _trim () {
    local var=$1;
    var="${var#"${var%%[![:space:]]*}"}";   # remove leading whitespace characters
    var="${var%"${var##*[![:space:]]}"}";   # remove trailing whitespace characters
    echo -n "$var";
}

# Test if a value is in the format of a valid IP4 Address
# Usage:
# if [[ $(_ip_valid $IP) ]]; then
#   echo 'IP is valid'
# else
#   echo 'Invalid IP'
# fi
function _ip_valid() {
  local _ip="$1"
  if [[ $_ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
	echo 1
  fi
}

# Gets if a file is older then a time passed in as minutes
# @param1 file to check
# @param2 Age of file in minutes
# Return 1 if file is older then time passed in; Otherwise, null
function _file_older() {
	local _file="$1"
	local _min="$2"
	if ! [[ $(stat -c %Y -- "${_file}") -lt $(date +%s --date="${_min} min ago") ]]; then
		echo 1
	fi
}

test -f $IP_LOGFILE || touch $IP_LOGFILE
test -f $OLD_IP_LOGFILE || touch $OLD_IP_LOGFILE
test -f $RESULT_LOGFILE || touch $RESULT_LOGFILE

# Check for a token file and if it exist then test to see if we can read it.
test -e "$TOKEN_FILE"
if [ $? -eq 0 ];then
    test -r "$TOKEN_FILE"
    if [ $? -ne 0 ];then
        echo "No read permissions for token file: $TOKEN_FILE" > $RESULT_LOGFILE
        exit 1
    fi
else
    echo "Unable to locate token file: $TOKEN_FILE" > $RESULT_LOGFILE
    exit 1
fi

test -e "$DOMAINS"
if [ $? -eq 0 ];then
    test -r "$DOMAINS"
    if [ $? -ne 0 ];then
        echo "No read permissions for domain file: $DOMAINS" > $RESULT_LOGFILE
        exit 1
    fi
else
    echo "Unable to locate domain file: $DOMAINS" > $RESULT_LOGFILE
    exit 1
fi

IP_VALID=0
if [[ -r "${TMP_FILE}" ]] && [[ $(_file_older "${TMP_FILE}" "${MAX_IP_AGE}") ]]; then
	IP=$(_trim $(cat "${TMP_FILE}"))
	IP_VALID=$(_ip_valid "${IP}")
	# echo 'Optained ip address from tmp file'
fi
if [[ $IP_VALID -ne 1 ]]; then
	IP=$(wget -qT 20 -O - "https://checkip.amazonaws.com/") && IP=$(_trim "$IP")
	IP_VALID=$(_ip_valid "${IP}")
	echo "${IP}" > "${TMP_FILE}"
	# echo 'Optained ip address Internet'
fi
if [[ $IP_VALID -ne 1 ]]; then
	echo 'Unable to optain valid ip address. Halting'
	exit 1
fi

TOKEN=$(cat $TOKEN_FILE)
GETLOGIP=$(cat $IP_LOGFILE)
RESULT=''

# write the previous ipaddress into the old ip log file
echo $GETLOGIP > $OLD_IP_LOGFILE

if [ -n "$IP" -a "$GETLOGIP" != "$IP" ]; then
    # empty the ip logfile
	# echo "ko" > $IP_LOGFILE
    truncate -s 0 "$IP_LOGFILE"

    while IFS="" read -r p || [ -n "$p" ]
    do
        # trim the current line of the domains.txt file
        D=$(_trim "$p");
        # make sure the currentt line is not empty
        if [[ -n "$D" ]]; then
            # printf '%s\n' "$D"
            echo url="https://www.duckdns.org/update?domains=$D&token=$TOKEN&ip=" | /usr/bin/curl -k -o $RESULT_LOGFILE -K -
            RESULT=$(cat $RESULT_LOGFILE)
            if [ $RESULT = "OK" ]; then
                
                # write the current ipaddress into the current ip log file
                echo $IP > $IP_LOGFILE
            else
                echo "bad ip" > $IP_LOGFILE
            fi
        fi
    done < "$DOMAINS"
fi
# Read the ip log file and confirm it contains a valid ip address format.
RESULT=$(cat $IP_LOGFILE | grep '^[0-9]\{1,3\}\(\.[0-9]\{1,3\}\)\{3\}$')
if [[ -n "$RESULT" ]]; then
    # Valid ip address format found
    # exit normally
    exit 0
fi
# bad ip address
# exit with an error code
exit 2