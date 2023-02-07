#!/bin/bash
# Author: George S (gstefanov)
# Date Created: 03/02/2023
# Date Modified: 07/02/2023
# Version: 1.1.0

# Description:
# This script is used to stop/start services on a node as per HyperStore documentation

# Usage
# ./manage_services.sh

service_mgmt() {
    local command=$1
    local service=$2
    systemctl $1 $2
}

perform_service_mgmt() {
    local action=$1
    local service_array=("${!2}")
    local loop_type=$3

    if [[ "$loop_type" == "forward" ]]; then
        for svc in "${service_array[@]}"; do
            echo "$action $svc"
            service_mgmt $action $svc
            echo "Exit status: $?"
            printf "%0.s=" $(seq 1 14)
            echo
        done
    elif [[ "$loop_type" == "reverse" ]]; then
        for ((svc=${#service_array[@]}-1; svc>=0; svc--)); do 
            echo "$action ${service_array[svc]}"
            service_mgmt $action ${service_array[svc]}
            echo "Exit status: $?"
            printf "%0.s=" $(seq 1 14)
            echo
        done
    fi
}

if [[ -z $(systemctl status cloudian-sqs | grep running) ]]; then
    start_stop=(cloudian-cassandra cloudian-redis-credentials cloudian-redis-qos cloudian-hyperstore cloudian-iam cloudian-s3 cloudian-redismon cloudian-agent cloudian-cmc)
    restart_status=(cloudian-redis-credentials cloudian-redis-qos cloudian-cassandra cloudian-redismon cloudian-hyperstore cloudian-s3 cloudian-cmc cloudian-agent cloudian-iam)
elif [[ -n $(systemctl status cloudian-sqs | grep running) ]]; then
    start_stop=(cloudian-cassandra cloudian-redis-credentials cloudian-redis-qos cloudian-hyperstore cloudian-sqs cloudian-iam cloudian-s3 cloudian-redismon cloudian-agent cloudian-cmc)
    restart_status=(cloudian-redis-credentials cloudian-redis-qos cloudian-cassandra cloudian-redismon cloudian-hyperstore cloudian-s3 cloudian-cmc cloudian-agent cloudian-sqs cloudian-iam)
fi

PS3="What action would you like to perform?: "
select action in Status Restart Start Stop Exit; do 
    case "$action" in
        Status)
            perform_service_mgmt status restart_status[@] forward
            ;;
        Restart)
            perform_service_mgmt restart restart_status[@] forward
            ;;
        Start)
            perform_service_mgmt start start_stop[@] forward
            ;;
        Stop)
            perform_service_mgmt stop start_stop[@] reverse
            ;;
        Exit)
            echo "Exiting the script."
            break
            ;;
        *)
            echo "Invalid option selected. Please choose a valid one."
            continue
            ;;
    esac    
done

echo "Check cloudian-dnsmasq manually."
