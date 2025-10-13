#! /bin/bash
# Author: George S (gstefanov)
# Date Created: 09/01/2023
# Date Modified: 10/10/2025
# Version: 4.0

# Description:
# Automates object uploads on the test cluster

# Usage
# ./put_bucket.sh
set -euo pipefail

DIR=$(dirname $0)
BUCKETS=()
REGION="region1"
PROFILE="testing"
PROFILE_MARKER="$DIR/${PROFILE}_configured"
BUCKET_MARKER="$DIR/${PROFILE}_buckets_created"
ENDPOINT_MARKER="$DIR/${PROFILE}_endpoint"

if [[ ! -f /usr/local/bin/aws ]]; then
        curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
        unzip awscliv2.zip
        sudo ./aws/install
fi

if [[ ! -f "$PROFILE_MARKER" ]]; then
        echo "Running first-time AWS configure..."
        aws configure --profile "$PROFILE"
        touch "$PROFILE_MARKER"
fi

if [[ ! -f "$ENDPOINT_MARKER" ]]; then
    read -p "Please specify S3 endpoint: " AWS_ENDPOINT
    echo "$AWS_ENDPOINT" > "$ENDPOINT_MARKER"
    echo "S3 endpoint saved to $ENDPOINT_MARKER"
else
    AWS_ENDPOINT=$(<"$ENDPOINT_MARKER")
    echo "Using stored S3 endpoint: $AWS_ENDPOINT"
fi

if [[ ! -f "$BUCKET_MARKER" ]]; then
        read -p "How many buckets would you like to create?: " BUCKET_COUNT
        if ! [[ "$BUCKET_COUNT" =~ ^[0-9]+$ ]]; then
                echo "Invalid number. Exiting."
                exit 1
        fi

        echo "Creating $BUCKET_COUNT buckets..."
        for x in $(seq 1 "$BUCKET_COUNT"); do
                BUCKET_NAME="bucket${x}"
                BUCKETS+=("bucket${x}")
                /usr/local/bin/aws s3api create-bucket \
                --bucket "$BUCKET_NAME" \
                --region "$REGION" \
                --endpoint="$AWS_ENDPOINT" \
                --profile "$PROFILE" >/dev/null 2>&1

                if [[ $? -eq 0 ]]; then
                        echo "$BUCKET_NAME ready for use."
                else
                        echo "Skipped or failed to create $BUCKET_NAME (might already exist)."
                fi
        done

        touch "$BUCKET_MARKER"
        echo "All buckets created. Marker stored at $BUCKET_MARKER."
fi

read -p "How many objects would you like to be uploaded?: " OBJ_COUNT
read -p "Specify the object size in bytes?: " OBJ_SIZE

for n in $(seq 1 "$OBJ_COUNT"); do
        dd if=/dev/urandom of=/root/random/file$(echo $RANDOM-$RANDOM).bin bs=1 count="$OBJ_SIZE" &>/dev/null
done

for BUCKET in $"${BUCKETS[@]}"; do
        /usr/local/bin/aws --no-verify-ssl --only-show-errors --endpoint=${AWS_ENDPOINT} --profile "$PROFILE" s3 cp /root/random/ s3://"$BUCKET" --recursive
        sleep 1
done

rm -rf /root/random/file*
echo "DONE"