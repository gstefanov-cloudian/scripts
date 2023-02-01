#!/bin/bash
# Author: George S (gstefanov)
# Date Created: 20/01/2023
# Date Modified: 31/01/2023
# Version: 1.0.3

# Description:
# This is an interactive script that can be used to change the NPROC and NOFILE limits

# Usage
# ./chlimit.sh

export NPROC_LIMIT=65535

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
    local PS3="What would you like to be the new NOFILE limit?: "
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
        esac
        for nofile in $nopen_files ; do
            sed "s|$nopen_limit|$newlim|g" $nofile
        done
    break
    done
}

# Update the /etc/security/limits.d/20-nproc.conf files on all nodes 
update_20_nproc_conf() {
    export curnp_limit=$(grep -Ew "cloudian (soft|hard) nproc" /etc/security/limits.d/20-nproc.conf | awk '{print$4}' | uniq)
    echo "The current limit in /etc/security/limits.d/20-nproc.conf is $curnp_limit"
    for NODE in $(awk '{print $3}' ${HOSTS_FILE} | sort); do
        ssh -i $SSH_KEY $NODE "sed 's|$curnp_limit|$NPROC_LIMIT|g' /etc/security/limits.d/20-nproc.conf"
    done
}

# Update the /etc/security/limits.conf files on all nodes
update_limits_conf() {
    export curnf_limit=$(grep -Ew "(soft|hard) nofile" /etc/security/limits.conf | awk '{print$4}' | uniq)
    echo "The current limit in /etc/security/limits.conf is $curnf_limit"
    for NODE in $(awk '{print $3}' ${HOSTS_FILE} | sort); do
        ssh -i $SSH_KEY $NODE "sed 's|$curnf_limit|$newlim|g' /etc/security/limits.conf"
    done
}

# Update the /etc/systemd/system.conf files on all nodes
update_system_conf() {
    export curNP_limit=$(grep ^LimitNPROC /etc/systemd/system.conf | awk -F '=' '{print$2}')
    echo "The current limit in /etc/systemd/system.conf is $curNP_limit"
    for NODE in $(awk '{print $3}' ${HOSTS_FILE} | sort); do
        ssh -i $SSH_KEY $NODE "sed 's|$curNP_limit|$NPROC_LIMIT|g' /etc/systemd/system.conf"
    done
}

# 1. Start a while loop that would first allow you to select the limit you want to change
# 2. Output all files that contain the limit
# 3. Then check if the limit is the same across all .erb files 
# 4. Ask if you want to change the limit and apply it everywhere if the answer is positive
counter=0
while [ $counter -lt 2 ]; do
    PS3="Select the limit that you want to check: "
    select limit in NPROC NOFILE Exit; do
        case "$limit" in
            NPROC) 
                echo -e "\n\tNPROC limit found in the following files: \n"
                nproc_files=$(for file in "${FILES[@]}"; do grep -l 'LimitNPROC=' "$file" ; done)
                echo "$nproc_files"
                nproc_conf_files
                ;;
            NOFILE)
                echo -e "\n\tNOFILE limit found in the following files: \n"
                nopen_files=$(for file in "${FILES[@]}"; do grep -l 'LimitNOFILE=' "$file" ; done)
                echo "$nopen_files"
                nopen_conf_files
                ;;
            Exit)
                echo "Exiting the script."
                exit 0
                ;;
        esac
    break
    done

    # Check what limit was chosen for modification, find what the current limit is and determine if it is the same across all files
    if [[ $limit == NPROC ]]; then
        nproc_limit=$(grep 'LimitNPROC=' $nproc_files | awk -F "=" '{print$2}' | uniq)
        unique_values=($(echo "${nproc_limit[@]}" | tr ' ' '\n' | sort -u | tr '\n' ' '))
            if [ ${#unique_values[@]} -ne ${#nproc_limit[@]} ]; then
                echo "Different limit values were found in the files:"
                echo ${unique_values[@]}
                read -r -p "Which value do you want to use as the current limit?: " limit_choice
                nproc_limit=$limit_choice
            fi
        echo "The current limit is $nproc_limit"
    elif [[ $limit == NOFILE ]]; then
        nopen_limit=$(grep 'LimitNOFILE=' $nopen_files | awk -F "=" '{print$2}' | uniq)
        unique_values=($(echo "${nopen_limit[@]}" | tr ' ' '\n' | sort -u | tr '\n' ' '))
            if [ ${#unique_values[@]} -ne ${#nopen_limit[@]} ]; then
                echo "Different limit values were found in the files:"
                echo ${unique_values[@]}
                read -r -p "Which value do you want to use as the current limit?: " limit_choice
                nopen_limit=$limit_choice
            fi
        echo "The current limit is $nopen_limit"
    fi

    # Ask if you want to change the limit and update it everywhere
    read -r -p "Do you want to change the limit? [y/n]: " inp1
    if [[ $inp1 == "y" || $inp1 == "Y" || $inp1 == "yes" || $inp1 == "Yes" ]] ; then
        case "$limit" in
            NPROC) 
                sed "s|$nproc_limit|$NPROC_LIMIT|g" $nproc_files
                update_20_nproc_conf
                update_system_conf
                echo $NPROC_LIMIT > /proc/sys/kernel/pid_max
                echo "The NPROC limit was increased to $NPROC_LIMIT."
                ;;
            NOFILE) 
                change_nofile_limit
                update_limits_conf
                echo "The NOFILE limit was increased to $newlim"
                ;;
        esac
    else
        exit 0
    fi
counter=$((counter + 1)) # Loop once more for the other limit type
done

echo "Check fs.file-max in /etc/sysctl.conf in case of a persistent NOFILE limit."
