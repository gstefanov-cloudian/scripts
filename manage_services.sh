#!/bin/bash
# Author: George S (gstefanov)
# Date Created: 03/02/2023
# Date Modified: 03/02/2023
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
    stop_order=(cloudian-cmc cloudian-agent cloudian-redismon cloudian-s3 cloudian-iam cloudian-hyperstore cloudian-redis-qos cloudian-redis-credentials cloudian-cassandra)
    start_order=(cloudian-cassandra cloudian-redis-credentials cloudian-redis-qos cloudian-hyperstore cloudian-iam cloudian-s3 cloudian-redismon cloudian-agent cloudian-cmc)
    restart_order=(cloudian-redis-credentials cloudian-redis-qos cloudian-cassandra cloudian-redismon cloudian-hyperstore cloudian-s3 cloudian-cmc cloudian-agent cloudian-iam)
    status_order=(cloudian-redis-credentials cloudian-redis-qos cloudian-cassandra cloudian-redismon cloudian-hyperstore cloudian-s3 cloudian-cmc cloudian-agent cloudian-iam)
elif [[ -n $(systemctl status cloudian-sqs | grep running) ]]; then
    stop_order=(cloudian-cmc cloudian-agent cloudian-redismon cloudian-s3 cloudian-iam cloudian-sqs cloudian-hyperstore cloudian-redis-qos cloudian-redis-credentials cloudian-cassandra)
    start_order=(cloudian-cassandra cloudian-redis-credentials cloudian-redis-qos cloudian-hyperstore cloudian-sqs cloudian-iam cloudian-s3 cloudian-redismon cloudian-agent cloudian-cmc)
    restart_order=(cloudian-redis-credentials cloudian-redis-qos cloudian-cassandra cloudian-redismon cloudian-hyperstore cloudian-s3 cloudian-cmc cloudian-agent cloudian-sqs cloudian-iam)
    status_order=(cloudian-redis-credentials cloudian-redis-qos cloudian-cassandra cloudian-redismon cloudian-hyperstore cloudian-s3 cloudian-cmc cloudian-agent cloudian-sqs cloudian-iam)
fi

PS3="What action would you like to perform?: "
select action in status restart start stop; do 
    case "$action" in
        status)
            for svc in "${status_order[@]}"; do service_mgmt status $svc | head -n3 ; done
            ;;
        restart)
            for svc in "${restart_order[@]}"; do service_mgmt restart $svc ; done
            ;;
        start)
            for svc in "${start_order[@]}"; do service_mgmt start $svc ; done
            ;;
        stop)
            for svc in "${stop_order[@]}"; do service_mgmt stop $svc ; done
            ;;
        *)
            echo "Invalid option selected. Please choose a valid one."
            continue
            ;;
    esac    
break
done

