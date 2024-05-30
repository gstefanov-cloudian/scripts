#!/bin/bash
# Author: George S (gstefanov)
# Date Created: 20/01/2023
# Date Modified: 07/02/2023
# Version: 1.1.0

# Description:
# This is an interactive script that can be used to change the NPROC and NOFILE limits

# Usage
# ./change_limits.sh

# Adding a few colors
RESTORE=$(echo -en '\001\033[0m\002')
LGREEN=$(echo -en '\001\033[01;32m\002')
LYELLOW=$(echo -en '\001\033[01;33m\002')
LRED=$(echo -en '\001\033[01;31m\002')
WHITE=$(echo -en '\001\033[01;37m\002')

echo "${WHITE}=================================${RESTORE}"
echo "${LGREEN}change_limits.sh was initiated...${RESTORE}"
echo "${WHITE}=================================${RESTORE}"

export NPROC_LIMIT=262144

# Get the common version without relying on HS CLI
VERSION=$(/opt/cloudian/bin/cloudian version | grep Version | awk '{print$2}')
PUPVER="${VERSION:0:5}"

# Get the cloudian-staging directory path without relying on HS CLI
INSTALL_SCRIPT=$(grep installscript /opt/cloudian/conf/cloudianservicemap.json | awk '{print $8}' | cut -d'"' -f2)
STAGING_DIR=$(dirname ${INSTALL_SCRIPT})

HOSTS_FILE=${STAGING_DIR}/hosts.cloudian
SSH_KEY=${STAGING_DIR}/cloudian-installation-key

# Create an array with all systemctl_*_service.erb files
readarray -t FILES < <(for modules in cassandra cloudians3 cloudianagent cmc; do 
find /etc/cloudian-"$PUPVER"-puppet/modules/$modules/templates/ -name 'systemctl_*' -type f -print  
done)

# Check if 20-nproc.conf and system.conf return non-empty string when checked for NPROC limit
nproc_conf_files() {
    if [[ -n $(grep -Ew "cloudian (soft|hard) nproc" /etc/security/limits.d/20-nproc.conf) ]]; then
        echo "/etc/security/limits.d/20-nproc.conf"
    fi
    if [[ -n $(grep ^LimitNPROC /etc/systemd/system.conf) ]]; then
        echo "/etc/systemd/system.conf"
    fi
}

# Check if limits.conf returns non-empty when checked for NOFILE limit 
nopen_conf_files() {
    if [[ -n $(grep -Ew "(soft|hard) nofile" /etc/security/limits.conf) ]]; then
        echo "/etc/security/limits.conf"
    fi
}

# NOFILE change limit function for systemctl_*_service.erb files with 3 options for the new limit
change_nofile_limit() {
    local PS3="${LYELLOW}What would you like to be the new NOFILE limit?:${RESTORE} "
    select newlim in 240000 500000 800000 ; do
        case "$newlim" in
            240000)
                export newlim=240000
                ;;
            500000)
                export newlim=500000
                ;;
            800000)
                export newlim=800000
                ;;
            *)
            echo "${LRED}Invalid option selected. Please choose a valid option.${RESTORE}"
            continue
            ;;
        esac
        for nofile in $nopen_files ; do
            sed -i "s|$nopen_limit|$newlim|g" $nofile
        done
    break
    done
}

update_node_limits_conf() {
    local file=$1
    local limit=$2
    local new_limit=$3
    local input

    if [[ $file == "/etc/security/limits.d/20-nproc.conf" ]]; then
        local cur_limit=$(grep -Ew "cloudian (soft|hard) $limit" $file | awk '{print $4}' | uniq)
    elif [[ $file == "/etc/systemd/system.conf" ]]; then
        local cur_limit=$(grep "^LimitNPROC" $file | awk -F '=' '{print $2}')
    elif [[ $file == "/etc/security/limits.conf" ]]; then
        local cur_limit=$(grep -Ew "(soft|hard) $limit" $file | awk '{print$4}' | uniq)
    fi

    echo
    echo "${WHITE}The current limit in${LRED} $file ${WHITE}is${LRED} $cur_limit ${RESTORE}"
    read -r -p "${LYELLOW}Do you want to change it? [y/n]:${RESTORE} " input
    if [[ $input =~ ^[yY][eE][sS]?|y|Y$ ]]; then
        for node in $(awk '{print $3}' $HOSTS_FILE | sort); do
        ssh -i $SSH_KEY $node "sed -i 's|$cur_limit|$new_limit|g' $file"
        done
    elif [[ $input =~ ^[nN][oO]?$ ]]; then
        echo "${WHITE}No changes applied to $file.${RESTORE}"
    else
        echo "${LRED}Invalid input. No changes applied to $file.${RESTORE}"
    fi
}

unique_values_func() {
    limit_array=("$1")
    local limit=$2
    unique_values=($(echo "${limit_array[@]}" | tr ' ' '\n' | sort -u | tr '\n' ' '))
    if [ ${#unique_values[@]} -ne ${#limit_array[@]} ]; then
        echo "${LRED}Different limit values were found in the files:${RESTORE}"
        echo ${unique_values[@]}
        read -r -p "${LYELLOW}Which value do you want to use as the current limit?:${RESTORE} " limit_choice
            if [[ $limit == NPROC ]]; then nproc_limit=$limit_choice
            elif [[ $limit == NOFILE ]];then nopen_limit=$limit_choice
            fi
    fi
}

echo_limit() {
    local limit=$1
    echo
    echo "${WHITE}The current limit in *.erb files is${LRED} $limit ${RESTORE}"
    echo
}

# 1. Start a while loop that would first allow you to select the limit you want to change
# 2. Output all files that contain the limit
# 3. Then check if the limit is the same across all .erb files 
# 4. Ask if you want to change the limit and apply it everywhere if the answer is positive
counter=0
while [ $counter -lt 2 ]; do
    PS3="${LYELLOW}Select the limit that you want to check:${RESTORE} "
    select limit in NPROC NOFILE Exit; do
        case "$limit" in
            NPROC) 
                echo -e "\n\t${WHITE}NPROC limit found in the following files:${RESTORE} \n"
                nproc_files=$(for file in "${FILES[@]}"; do grep -l 'LimitNPROC=' "$file" ; done)
                echo "$nproc_files"
                nproc_conf_files
                ;;
            NOFILE)
                echo -e "\n\t${WHITE}NOFILE limit found in the following files:${RESTORE} \n"
                nopen_files=$(for file in "${FILES[@]}"; do grep -l 'LimitNOFILE=' "$file" ; done)
                echo "$nopen_files"
                nopen_conf_files
                ;;
            Exit)
                echo "${WHITE}Exiting the script.${RESTORE}"
                exit 0
                ;;
            *)
                echo -e "${LRED}Invalid option selected. Please choose a valid option.${RESTORE}"
                continue
                ;;
        esac
    break
    done

    # Check what limit was chosen for modification, find what the current limit is and determine if it is the same across all files
    if [[ $limit == NPROC ]]; then
        nproc_limit=$(grep 'LimitNPROC=' $nproc_files | awk -F "=" '{print$2}' | uniq)
        unique_values_func "${nproc_limit[@]}" nproc_limit
        echo_limit $nproc_limit
    elif [[ $limit == NOFILE ]]; then
        nopen_limit=$(grep 'LimitNOFILE=' $nopen_files | awk -F "=" '{print$2}' | uniq)
        unique_values_func "${nopen_limit[@]}" nopen_limit
        echo_limit $nopen_limit
    fi

    # Ask if you want to change the limit and update it everywhere
    read -r -p "${LYELLOW}Do you want to change the limit? [y/n]:${RESTORE} " inp1
    if [[ $inp1 == "y" || $inp1 == "Y" || $inp1 == "yes" || $inp1 == "Yes" ]] ; then
        case "$limit" in
            NPROC) 
                sed -i "s|$nproc_limit|$NPROC_LIMIT|g" $nproc_files
                update_node_limits_conf "/etc/security/limits.d/20-nproc.conf" "nproc" $NPROC_LIMIT
                update_node_limits_conf "/etc/systemd/system.conf" "NPROC" $NPROC_LIMIT
                echo $NPROC_LIMIT > /proc/sys/kernel/pid_max
                echo
                echo "${WHITE}The NPROC limit was increased to${LRED} $NPROC_LIMIT ${RESTORE}"
                echo
                ;;
            NOFILE) 
                change_nofile_limit
                update_node_limits_conf "/etc/security/limits.conf" "nofile" $newlim
                echo
                echo "${WHITE}The NOFILE limit was increased to${LRED} $newlim ${RESTORE}"
                echo
                echo "${WHITE}Check fs.file-max in /etc/sysctl.conf in case of a persistent NOFILE limit.${RESTORE}"
                echo
                ;;
        esac
    elif [[ $inp1 == "n" || $inp1 == "N" || $inp1 == "no" || $inp1 == "No" ]] ; then
        echo "${WHITE}Sure thing. No changes will be applied. Exiting...${RESTORE}"
        exit 0
    else
        echo "${WHITE}Invalid input. Exiting..."
        exit 0
    fi
counter=$((counter + 1)) # Loop once more for the other limit type
done

echo "${WHITE}=================================${RESTORE}"
echo "${WHITE}==========[${RESTORE}${LGREEN}That was it${RESTORE}${WHITE}]==========${RESTORE}"
echo "${WHITE}=================================${RESTORE}"