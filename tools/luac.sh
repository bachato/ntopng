#!/bin/sh

LUAC=`which luac`
MV=`which mv`
TMP_FILE="/tmp/luac.out"

if [ "$#" -ne 1 ]; then    
    echo "Usage: luac.sh <filename>"
    echo ""
    echo "This tool replaces a lua file with its bytecode"
    exit
fi


$LUAC -o /tmp/luac.out $1

if test -f $TMP_FILE; then
    $MV /tmp/luac.out $1
fi


