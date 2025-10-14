#!/bin/bash
# Author: George S (gstefanov)
# Date Created: 10/10/2025
# Date Modified: 
# Version: 1.1

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
      USER=$(ssh -i /export/home/cloudian/cloudian-installation-key "${MASTER}" "hsctl config get admin.auth.username")
      PASS=$(ssh -i /export/home/cloudian/cloudian-installation-key "${MASTER}" "hsctl config get admin.auth.password")
    else
      USER=$(hsctl config get admin.auth.username)
      PASS=$(hsctl config get admin.auth.password)
    fi
    curl -X POST -k -u "${USER}:${PASS}" https://localhost:19443/bucketops/purge?bucketName="${BUCKET}" </dev/null
}

# Run
mkdir -p "$PURGE_HOME"
cd "$PURGE_HOME" || exit

while read -r BUCKET; do
    [[ -z "$BUCKET" ]] && continue  # skip empty lines
    purge_api
    $PURGE -b "$BUCKET" </dev/null
    $PURGE -b "$BUCKET" -file "${BUCKET}.purged.partitions.1.log" -t 15 -dry n </dev/null
done < "${DIR}/${BUCKET_LIST}"