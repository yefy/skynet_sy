#!/bin/bash
#cd ./study/protos
cd ./study/protos
rm *.pb
protoName="protoName"
>protoName
for file in $(ls ./)
do
    echo $file
    prefix=${file%.*}
    echo $prefix
    suffix=${file##*.}
    echo $suffix
    if [ "$suffix" = "proto" ]
    then
        echo "create $prefix.pb"
	    protoc --descriptor_set_out $prefix.pb $prefix.proto
	    echo $prefix.pb >> $protoName
    fi
done
#cd -
#killall -9 skynet
#./skynet study/switch/switch_config &
#sleep 1s
#./skynet study/chat/chat_config &
