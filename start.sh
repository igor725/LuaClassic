#!/bin/bash

ABSOLUTE_FILENAME=`readlink -e "$0"`;
DIRECTORY=`dirname "$ABSOLUTE_FILENAME"`;
cd $DIRECTORY;

st=true

while $st ; do
	luajit main.lua
	if [ $? -ne 2 ]; then
		st=false
	fi
done
