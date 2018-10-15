#!/bin/bash

mkdir /usr/share/kcompose
cp ./kcompose.sh /usr/share/kcompose/
cp -r ./kafka /usr/share/kcompose/kafka
chmod +x /usr/share/kcompose/kcompose.sh
ln -s /usr/share/kcompose/kcompose.sh /usr/bin/kcompose 