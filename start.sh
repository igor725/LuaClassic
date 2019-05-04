#!/bin/bash
st=true

while $st ; do
	luajit main.lua
	if [ $? -ne 2 ]; then
		st=false
	fi
done
