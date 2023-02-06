#!/bin/bash
# Author: George S (gstefanov)
# Date Created: 03/02/2023
# Date Modified: 06/02/2023
# Version: 1.0.0

# Description:
# This script is used to stop/start services on a node as per HyperStore documentation

# Usage
# ./restart_services.sh

service_mgmt() {
    local command=$1
    local service=$2
    systemctl $1 $2
}

if [[ -z $(systemctl status cloudian-sqs | grep running) ]]; then
    start_stop=(cloudian-cassandra cloudian-redis-credentials cloudian-redis-qos cloudian-hyperstore cloudian-iam cloudian-s3 cloudian-redismon cloudian-agent cloudian-cmc)
    restart_status=(cloudian-redis-credentials cloudian-redis-qos cloudian-cassandra cloudian-redismon cloudian-hyperstore cloudian-s3 cloudian-cmc cloudian-agent cloudian-iam)
elif [[ -n $(systemctl status cloudian-sqs | grep running) ]]; then
    start_stop=(cloudian-cassandra cloudian-redis-credentials cloudian-redis-qos cloudian-hyperstore cloudian-sqs cloudian-iam cloudian-s3 cloudian-redismon cloudian-agent cloudian-cmc)
    restart_status=(cloudian-redis-credentials cloudian-redis-qos cloudian-cassandra cloudian-redismon cloudian-hyperstore cloudian-s3 cloudian-cmc cloudian-agent cloudian-sqs cloudian-iam)
fi

PS3="What action would you like to perform?: "
select action in status restart start stop; do 
    case "$action" in
        status)
            for svc in "${restart_status[@]}"; do 
                service_mgmt status $svc | head -n3
            done
            ;;
        restart)
            for svc in "${restart_status[@]}"; do 
                echo "Restarting $svc"
                service_mgmt restart $svc 
            done
            ;;
        start)
            for svc in "${start_stop[@]}"; do 
                echo "Starting $svc"
                service_mgmt start $svc  
            done
            ;;
        stop)
            for svc in $(seq $((${#start_stop[@]}-1)) -1 0); do 
                echo "Stopping $svc"
                service_mgmt stop $svc
            done
            ;;
        *)
            echo "Invalid option selected. Please choose a valid one."
            continue
            ;;
    esac    
break
done

