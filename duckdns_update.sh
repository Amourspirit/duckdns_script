#!/bin/bash

#region License

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

#endregion

#region Script Info
# Script to update one or more ip address with the free service duckdns.org
# Created by Paul Moss
# Created: 2020-06-19
# Updated: 2020-07-08
# File Name: duckdns_update.sh
# Github: https://github.com/Amourspirit/duckdns_script
# Version 1.1.0
#endregion

#region Default Settings
VER='1.1.0'
CONFIG_FILE="$HOME/.duckdns/config.cfg"
TOKEN_FILE="$HOME/.duckdns/token"
IP=0
IP_LOGFILE="$HOME/.duckdns/log/ip.log"
OLD_IP_LOGFILE="$HOME/.duckdns/log/ip_old.log"
RESULT_LOGFILE="$HOME/.duckdns/log/duckdns.log"
DOMAINS="$HOME/.duckdns/domains.txt"
TMP_IP_FILE='/tmp/current_ip_address'
# Age in minutes to keep ipaddress store in tmp file
MAX_IP_AGE=5
#endregion

#region Functions
#region _trim()

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
function _trim() {
    local var=$1
    var="${var#"${var%%[![:space:]]*}"}" # remove leading whitespace characters
    var="${var%"${var##*[![:space:]]}"}" # remove trailing whitespace characters
    echo -n "$var"
}
#endregion

#region _ip_valid()

# Test if a value is in the format of a valid IP4 Address
# Usage:
# if [[ $(_ip_valid $IP) ]]; then
#   echo 'IP is valid'
# else
#   echo 'Invalid IP'
# fi
function _ip_valid() {
    local _ip="$1"
    if (! [[ -z $_ip ]]) && [[ $_ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        echo 1
    fi
}
#endregion

#region _file_older()

# Gets if a file is older then a time passed in as minutes
# @param1 file to check
# @param2 Age of file in minutes
# @return 1 if file is older then time passed in; Otherwise, null
# @example:
# if [[ $(_file_older "${FILE}" 5) ]]; then;
#    echo 'File
# fi
function _file_older() {
    local _file="$1"
    local _min="$2"
    if ! [[ $(stat -c %Y -- "${_file}") -lt $(date +%s --date="${_min} min ago") ]]; then
        echo 1
    fi
}
#endregion

#region _get_cfg_section()

# Populates and array name and value or only values from a section of a config file
# @param: ByRef array (bash 4.3+). The array to populate.
#   Passed in a actual array name such as SCRTIP_CFG and not ${SCRIPT_CFG}
#   If @param 4 is non-zero value this array must be a value only array as shown in second example
# @param: The path to file configuration file containing the section to read.
# @param: The case sensitive name of the section to read from file
# @param: Optional: If set to non-zero then will fill array with values only. Default 0
# @return: 0 if no errors were encountered. 3 if there was no name and value to read. 2 if unable to read config file because it does not exist or no read permissin
# @requires: function _trim
# @example: name and values
# CONFIG_FILE="$HOME/.hidden_dir/main.cfg" # https://pastebin.com/2iEH2jE6
# # create an array that contains configuration values
# typeset -A ZONE_CONF # init array
# ZONE_CONF=( # set default values in config array
#     [ZONE_LOCAL]='${HOME}/scripts/bind9/tmp/named.conf.local'
#       [ZONE_NAME]='Far Zone'
# )
# _get_cfg_section ZONE_CONF ${CONFIG_FILE} 'BIND'
#
# ZONE_CONF[ZONE_LOCAL]=$(eval echo "${ZONE_CONF[ZONE_LOCAL]}")
# echo 'Local:' "${ZONE_CONF[ZONE_LOCAL]}"
# echo 'Name:' "${ZONE_CONF[ZONE_NAME]}"
# unset ZONE_CONF # done with array, release memory
#
# @example: values only
# DOMAINS_CONF=()
# _get_cfg_section DOMAINS_CONF ${CONFIG_FILE} 'DOMAINS' 1
# printf '%s\n' "${DOMAINS_CONF[@]}"
# unset DOMAINS_CONF # done with array, release memory
function _get_cfg_section() {
    local -n _arr=$1
    local _file=$2
    local _section=$3
    local _section_name=''
    local _name=''
    local _value=''
    local _tmp_config_common_file=''
    local _line=''
    local _retval=0
    local _a_type=0
    if ! [[ -z $4 ]]; then
        _a_type=$4
    fi
    if [[ -r "${_file}" ]]; then
        _tmp_config_common_file=$(mktemp) # make tmp file to hold section of config.ini style section in
        # sed in this case takes the value of section and reads the setion from contents of 'file'
        sed -n '0,/'"${_section}"']/d;/\[/,$d;/^$/d;p' "${_file}" >${_tmp_config_common_file}
        test -s "${_tmp_config_common_file}" # test to to see if it is greater then 0 in size
        if [ $? -eq 0 ]; then
            if [[ _a_type -ne 0 ]]; then
                # read the input of the tmp config file line by line
                while read _line; do
                    _value=$(_trim "${_line#*=}")
                    if ! [[ -z "${_value}" ]]; then
                        _arr+=("${_value}")
                    fi
                done <"${_tmp_config_common_file}"
                _retval="$?"
            else
                # read the input of the tmp config file line by line
                while read _line; do
                    if [[ "${_line}" =~ ^[^#]*= ]]; then
                        _name=$(_trim "${_line%%=*}")
                        _value=$(_trim "${_line#*=}")
                        _arr[$_name]="${_value}"
                    fi
                done <"${_tmp_config_common_file}"
                _retval="$?"
            fi
        else
            _retval=3
        fi
        unlink ${_tmp_config_common_file} # release the tmp file that is contains the current section values
    else
        _retval=2
    fi
    return ${_retval}
}
#endregion

#region _int_assign()

# Assigns a interger value to first param if second param is a valid integer.
# @param: ByRef integer
# @param: The integer to assign to first param. Only gets assigned if valid integer
# @returns: returns 0 if second parameter was assigned to first parameter; Otherwise, 1
# example:
# myint=2; oth_int=10
# _int_assign myint $oth_int
# echo $myint
function _int_assign() {
    local -n int=$1
    local newval=$2
    # note: single [ ] is required
    [ "$newval" -eq "$newval" ] 2>/dev/null && int=$newval && return 0 || return 1
}
#endregion
#endregion

#region Read Configuraton from File
DOMAINS_ARR=()
test -r "${CONFIG_FILE}"
if [ $? -eq 0 ]; then
    # create an array that contains general configuration values
    typeset -A GEN_CONF # init array
    GEN_CONF=(# set default values in config array
        [IP_LOGFILE]="${IP_LOGFILE}"
        [OLD_IP_LOGFILE]="${OLD_IP_LOGFILE}"
        [RESULT_LOGFILE]="${RESULT_LOGFILE}"
        [TMP_IP_FILE]="${TMP_IP_FILE}"
        [MAX_IP_AGE]="${MAX_IP_AGE}"
    )
    _get_cfg_section GEN_CONF ${CONFIG_FILE} 'GENERAL'

    for key in $(eval echo \$\{'!'${GEN_CONF}[@]\}); do
        GEN_CONF["${key}"]="$(eval echo \$\{${GEN_CONF}[${key}]\})"
    done

    IP_LOGFILE="${GEN_CONF[IP_LOGFILE]}"
    OLD_IP_LOGFILE="${GEN_CONF[OLD_IP_LOGFILE]}"
    RESULT_LOGFILE="${GEN_CONF[RESULT_LOGFILE]}"
    TMP_IP_FILE="${GEN_CONF[TMP_IP_FILE]}"
    MAX_IP_AGE="${GEN_CONF[MAX_IP_AGE]}"
    unset GEN_CONF # done with array, release memory

    _get_cfg_section DOMAINS_ARR ${CONFIG_FILE} 'DOMAINS' 1
fi
#endregion

#region getopts
HELP_USAGE=0
# if a parameter does not require an argument such as -h -v then do not follow with :
usage() {
    echo "$(basename $0) usage:" && grep "[[:space:]].)\ #" $0 | sed 's/#//' | sed -r 's/([a-z])\)/-\1/'
    if [[ $HELP_USAGE -eq 0 ]]; then
        exit 0
    fi
}
while getopts "hvd:k:m:i:t:o:r:p:" arg; do
    case $arg in
    d) # Comma seperated domain name(s) such as www.domain.tld,lib.domain.tld,sales.domain.tld
        IFS=',' read -ra DOMAINS_ARR <<<"${OPTARG}"
        ;;
    k) # The path to the token File
        TOKEN_FILE="$(eval ${OPTARG})"
        ;;
    m) # The full path to named.conf file. Default: /etc/bind/named.conf
        ZONE_MAIN="${OPTARG}"
        ;;
    i) # The ip address to be used. Default the the ip address provided by: https://checkip.amazonaws.com/
        IP="${OPTARG}"
        if ! [[ $(_ip_valid "${IP}") ]]; then
            echo 'Not a valid ip address. Use IP 4 format'
            usage
            exit 1
        fi
        ;;
    t) # The amount of time the IP address is cached in minutes. Default is 5
        _int_assign MAX_IP_AGE ${OPTARG}
        ;;
    o) # The path to the old Log File
        OLD_IP_LOGFILE="$(eval ${OPTARG})"
        ;;
    r) # The path to the results log file.
        RESULT_LOGFILE="$(eval ${OPTARG})"
        ;;
    p) # The path to the cached IP address
        TMP_IP_FILE="$(eval ${OPTARG})"
        ;;
    v) # Display version info
        echo "$(basename $0) version: ${VER}"
        exit 0
        ;;
    h) # Display help.
        HELP_USAGE=1
        usage
        HELP_INDENT='          '
        echo "${HELP_INDENT}"'Option -d is required if [DOMAINS] section of configuration file is void'
        echo "${HELP_INDENT}"'See Also: https://github.com/Amourspirit/duckdns_script'
        exit 0
        ;;
    esac
done
shift $((OPTIND - 1))
if [ ${#DOMAINS_ARR[@]} -eq 0 ]; then
    usage
fi
#endregion

#region Settings Tests
test -f "${RESULT_LOGFILE}" || touch "${RESULT_LOGFILE}"
if ! [[ -f "${RESULT_LOGFILE}" ]]; then
    echo 'Path' "${RESULT_LOGFILE}" 'is not valid.'
    echo 'Terminating with Error'
    exit 1
fi

test -f "${IP_LOGFILE}" || touch "${IP_LOGFILE}"
if ! [[ -f "${IP_LOGFILE}" ]]; then
    echo 'Path' "${IP_LOGFILE}" 'is not valid.' >${RESULT_LOGFILE}
    echo 'Terminating with Error' >${RESULT_LOGFILE}
    exit 1
fi
test -f "${OLD_IP_LOGFILE}" || touch "${OLD_IP_LOGFILE}"
if ! [[ -f "${OLD_IP_LOGFILE}" ]]; then
    echo 'Path' "${OLD_IP_LOGFILE}" 'is not valid.' >${RESULT_LOGFILE}
    echo 'Terminating with Error' >${RESULT_LOGFILE}
    exit 1
fi

# Check for a token file and if it exist then test to see if we can read it.
test -e "${TOKEN_FILE}"
if [ $? -eq 0 ]; then
    test -r "${TOKEN_FILE}"
    if [ $? -ne 0 ]; then
        echo "No read permissions for token file: ${TOKEN_FILE}" >${RESULT_LOGFILE}
        exit 1
    fi
else
    echo "Unable to locate token file: ${TOKEN_FILE}" >${RESULT_LOGFILE}
    exit 1
fi

test -e "${DOMAINS}"
if [ $? -eq 0 ]; then
    test -r "${DOMAINS}"
    if [ $? -ne 0 ]; then
        echo "No read permissions for domain file: ${DOMAINS}" >${RESULT_LOGFILE}
        exit 1
    fi
else
    echo "Unable to locate domain file: ${DOMAINS}" >${RESULT_LOGFILE}
    exit 1
fi

test -e "${TMP_IP_FILE}"
if [ $? -eq 0 ]; then
    test -r "${TMP_IP_FILE}"
    if [ $? -ne 0 ]; then
        echo "No read permissions for domain file: ${TMP_IP_FILE}" >${RESULT_LOGFILE}
        exit 1
    fi
else
    echo "Unable to locate domain file: ${TMP_IP_FILE}" >${RESULT_LOGFILE}
    exit 1
fi
#endregion

#region get ip address
IP_VALID=0
if [[ -r "${TMP_IP_FILE}" ]] && [[ $(_file_older "${TMP_IP_FILE}" "${MAX_IP_AGE}") ]]; then
    IP=$(_trim $(cat "${TMP_IP_FILE}"))
    IP_VALID=$(_ip_valid "${IP}")
    # echo 'Optained ip address from tmp file'
fi
if [[ $IP_VALID -ne 1 ]]; then
    IP=$(wget -qT 20 -O - "https://checkip.amazonaws.com/") && IP=$(_trim "$IP")
    IP_VALID=$(_ip_valid "${IP}")
    echo "${IP}" >"${TMP_IP_FILE}"
    # echo 'Optained ip address Internet'
fi
if [[ $IP_VALID -ne 1 ]]; then
    echo 'Unable to optain valid ip address. Halting'
    exit 1
fi
#endregion

TOKEN=$(cat ${TOKEN_FILE})
GETLOGIP=$(cat ${IP_LOGFILE})
RESULT=''

# write the previous ipaddress into the old ip log file
echo ${GETLOGIP} >${OLD_IP_LOGFILE}

if [ -n "$IP" -a "$GETLOGIP" != "$IP" ]; then
    # empty the ip logfile
    # echo "ko" > $IP_LOGFILE
    truncate -s 0 "$IP_LOGFILE"
    for DOMAIN_NAME in "${DOMAINS_ARR[@]}"; do
        # trim the current line of the domains.txt file
        D=$(_trim "${DOMAIN_NAME}")
        # make sure the currentt line is not empty
        if [[ -n "$D" ]]; then
            # printf '%s\n' "$D"
            echo url='https://www.duckdns.org/update?domains='"${D}"'&token='"${TOKEN}"'&ip=' | /usr/bin/curl -k -o "${RESULT_LOGFILE}" -K -
            RESULT=$(cat ${RESULT_LOGFILE})
            if [ ${RESULT} = "OK" ]; then
                # write the current ipaddress into the current ip log file
                echo ${IP} >${IP_LOGFILE}
            else
                echo "bad ip" >${IP_LOGFILE}
            fi
        fi
    done
fi
# Read the ip log file and confirm it contains a valid ip address format.
RESULT=$(cat ${IP_LOGFILE} | grep '^[0-9]\{1,3\}\(\.[0-9]\{1,3\}\)\{3\}$')
if [[ -n "${RESULT}" ]]; then
    # Valid ip address format found
    # exit normally
    exit 0
fi
# bad ip address
# exit with an error code
exit 2
