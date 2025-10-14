#!/bin/bash
# Author: George S (gstefanov)
# Date Created: 10/10/2025
# Date Modified: 14/10/2025
# Version: 1.3

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

if [ ! -f "$PURGE" ]; then
  echo "Purge tool not found at $PURGE"
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
    mkdir -p "${PURGE_HOME}/${BUCKET}_purge" ; cd "${PURGE_HOME}/${BUCKET}_purge" || exit
    LOGFILE="${PURGE_HOME}/${BUCKET}_purge/purge_script.log"
    {
      purge_api
      $PURGE -b "$BUCKET"
      $PURGE -b "$BUCKET" -file "${BUCKET}.purged.partitions.1.log" -t 15 -dry n
    } 2>&1 | tee -a "$LOGFILE"
    cd "$PURGE_HOME" || exit
done 3< "${DIR}/${BUCKET_LIST}" 

echo "=== Script finished at $(date '+%F %T') ==="