#!/usr/bin/env bash
# 
# Process files in single handlers based on their extension.
#
# GPL-3.0 2016 Baryshnikov Alexander <dev@baryshnikov.net>
#
# Handler gets file to process as first argument.
# Handler MUST NOT remove source file.
# If processing finshed with zero code (SUCCESS), then file will be removed.
# If file is busy - it will no be processed.
# Script automatically created all required folders
#
# usage: ./run.sh [workdir]
#
# if workdir not set, current directory will be used
#
# Environment variables:
#
# * MAXLOGSIZE - positive number of bytes of log file before gzip
#
# Special requirements:
# 
# lsof - detect that file is busy
# ts (moreutils) - timestamping messages
#
# Handlers mapping example:
# 
# Filename          Handler
# file.abcd         abcd
# file2.abcd        abcd
# test              test
# 22test            22test
#
# Directories
#
# * handlers/ - contains executable handlers
# * pool/     - incoming files
# * logs/     - saved logs. Each log file has name same as handler
# 
# Log politics:
#
# Each log file with size more them MAXLOGSIZE will be gzipped (and replaced)

set -o pipefail
WORK_DIR="${1:-.}"
HANDLERS_DIR="$WORK_DIR/handlers"
POOL="$WORK_DIR/pool"
LOGS="$WORK_DIR/logs"
MAXLOGSIZE=${MAXLOGSIZE:-8388608} # 8 MB - 8388608
TIME="[%F %H:%M:%.S]"

mkdir -p "$POOL" "$HANDLERS_DIR" "$LOGS"

find "$POOL"/ -type f | while read file; do
    if  ! lsof "$file" >> /dev/null 2>&1; then
        echo "$file"
        filename=$(basename "$file")
        extension="${filename##*.}"
        if [ "1$extension" == "1" ] || [ "$extension" == "$filename" ]; then
            extension="main"
        fi        
        echo "Found $file"                       | ts "$TIME [SYS]" >> "$LOGS/$extension.log"
        if test -x "$HANDLERS_DIR/$extension"; then
            echo "Handler: $HANDLERS_DIR/$extension" | ts "$TIME [SYS]" >> "$LOGS/$extension.log"
            
            if ./"$HANDLERS_DIR"/"$extension" "$file" 2>&1  | ts "$TIME [HANDLER]" >> "$LOGS/$extension.log" ; then
                rm -f "$file"
                echo "Removed $file"     | ts "$TIME [SYS]"  >> "$LOGS/$extension.log"
            else
                echo "Not removed $file" | ts "$TIME [SYS]"  >> "$LOGS/$extension.log"
            fi
        else
            echo "Handler: $HANDLERS_DIR/$extension not found" | ts "$TIME [SYS]" >> "$LOGS/$extension.log"
        fi
    fi
done

# Clean logs

find "$LOGS"/ -type f -name '*.log' | while read log; do
    size=$(stat --printf "%s" "$log")
    if [ $size -gt $MAXLOGSIZE ]; then
        gzip -f "$log"
    fi
done
