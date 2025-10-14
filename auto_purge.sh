#!/bin/bash
# Author: George S (gstefanov)
# Date Created: 10/10/2025
# Date Modified: 
# Version: 1.2

# Description:
# Automates the purge of multiple buckets

# Usage
# ./auto_purge.sh <file>
# set -euo pipefail

# Variables
DIR="$(cd "$(dirname "$0")" && pwd)"
BUCKET_LIST=$1
PURGE_HOME=/root/purge
PURGE=/root/cloudian-bucket-tools/bin/cloudian-bucket-purge
MASTER=$(grep -A5 installscript /opt/cloudian/conf/cloudianservicemap.json | grep hostname | awk -F'"' '{print$4}')

# Checks
if [ $# -ne 1 ]; then
  echo "Usage: $0 <file>"
  echo "<file> should contain one bucket per line."
  exit 1
fi

if [ ! -f "$BUCKET_LIST" ]; then
  echo "Error: File $BUCKET_LIST does not exist."
  echo "Usage: $0 <file>"
  exit 1
fi

if [ ! -s "$BUCKET_LIST" ]; then
  echo "Error: File $BUCKET_LIST is empty."
  exit 1
fi

# Functions
purge_api () {
    local USER PASS
    if [[ "${MASTER}" != "${HOSTNAME}" ]] ; then
      USER=$(ssh -o StrictHostKeyChecking=no -i /export/home/cloudian/cloudian-installation-key "${MASTER}" "hsctl config get admin.auth.username")
      PASS=$(ssh -o StrictHostKeyChecking=no -i /export/home/cloudian/cloudian-installation-key "${MASTER}" "hsctl config get admin.auth.password")
    else
      USER=$(hsctl config get admin.auth.username)
      PASS=$(hsctl config get admin.auth.password)
    fi
    curl -X POST -k -u "${USER}:${PASS}" https://localhost:19443/bucketops/purge?bucketName="${BUCKET}"
}

# Run
mkdir -p "$PURGE_HOME"
cd "$PURGE_HOME" || exit

while IFS= read -r BUCKET <&3 || [[ -n "$BUCKET" ]] ; do
    [[ -z "$BUCKET" ]] && continue  # skip empty lines
    purge_api
    $PURGE -b "$BUCKET"
    nohup $PURGE -b "$BUCKET" -file "${BUCKET}.purged.partitions.1.log" -t 15 -dry n &
    # Capture background PID 
    jobs
    PURGE_PID=$!
    echo "Started background purge for ${BUCKET} (PID: $PURGE_PID)"
    # Check if a purge is running
    while kill -0 "$PURGE_PID" 2>/dev/null; do
        echo "$(date '+%F %T') - Purge for ${BUCKET} still running. Sleeping 30 minutes..."
        sleep 1 #1800  # 30 minutes
    done
    # Finish
    echo "$(date '+%F %T') - Purge for ${BUCKET} finished, continuing to next bucket."
done 3< "${DIR}/${BUCKET_LIST}"