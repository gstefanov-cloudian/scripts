#!/bin/bash
# Author: George S (gstefanov)
# Date Created: 10/10/2025
# Date Modified: 
# Version: 1.0

# Description:
# Automates the purge of multiple buckets

# Usage
# ./auto_purge.sh <file>
set -euo pipefail

# Variables
BUCKET_LIST=$1
PURGE_HOME=/root/purge
PURGE=/root/cloudian-bucket-tools/bin/cloudian-bucket-purge

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
    curl -X POST -k -u $(hsctl config get admin.auth.username):$(hsctl config get admin.auth.password) https://localhost:19443/bucketops/purge?bucketName="$BUCKET"
}

# Run
mkdir -p "$PURGE_HOME"
cd "$PURGE_HOME"

while IFS= read -r BUCKET; do
    [[ -z "$BUCKET" ]] && continue  # skip empty lines
    purge_api
    $PURGE -b "$BUCKET"
    $PURGE -b "$BUCKET" -file ${BUCKET}.purged.partitions.1.log -t 15 -dry n
done < "$BUCKET_LIST"
