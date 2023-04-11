#!/bin/bash
# Author: George S (gstefanov)
# Date Created: 11/04/2023
# Date Modified: 11/04/2023
# Version: 1.0

# Description:
# This script is used to download and monitor download progress of customer diagnostic logs manually uploaded to Cloudian S3.
# You need to prepare a file and insert each URL on a new line, then pass that file as an argument to the script.

# Usage: 
# ./wget_script.sh URLs.txt
# Where URLs.txt is a list of all Public Access URLs generated from CMC

LYELLOW=$(echo -en '\001\033[01;33m\002')
LGREEN=$(echo -en '\001\033[01;32m\002')
RESTORE=$(echo -en '\001\033[0m\002')

if [ $# -ne 1 ]; then
  echo "Usage: $0 <file>"
  echo "Where <file> is a file containing one URL per line."
  exit 1
fi

dir=$(dirname $0)
obj_urls=$1
output_file="progress.txt"
echo "" > $output_file

if [ ! -f "$obj_urls" ]; then
  echo "Error: File $obj_urls does not exist."
  echo "Usage: $0 <file>"
  echo "Where <file> is a file containing one URL per line."
  exit 1
fi

if [ ! -s "$obj_urls" ]; then
  echo "Error: File $obj_urls is empty."
  echo "Please add one or more URLs to the file."
  exit 1
fi

for URL in $(cat ${obj_urls}); do
	OBJ=$(basename "$URL" | cut -d"?" -f1) 
	wget -b -O "$OBJ" "$URL" &> /dev/null 2>> wget-errors.log  
done

echo "$LGREEN Download started!$RESTORE"
loading() {
        echo -n "$LGREEN Download in progress$RESTORE"
        for i in {1..3}; do
                echo -n "."
                sleep 1
        done
        echo -ne "\r$LGREEN Download in progress$RESTORE   \r"
}
(
count=$(wc -l < $obj_urls)
completed=0
while [ $completed -ne $count ]; do
	for x in $(find . -maxdepth 1 -name 'wget-log*'); do 
		if [[ -n $(tail $x | grep FINISHED) ]]; then
			completed=$((completed + 1))	
		fi
		loading > $output_file
	done
done

echo "$LYELLOW Download complete!$RESTORE"
echo "" > $output_file

for extract in $(ls *.tar.gz); do
	tar zxf $extract;
done
echo "$LYELLOW Logs extracted in $dir $RESTORE") &
disown
