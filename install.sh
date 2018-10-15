#!/bin/bash

mkdir -p $DESTDIR/usr/share/kcompose
mkdir -p $DESTDIR/usr/bin
cp ./kcompose.sh $DESTDIR/usr/share/kcompose/
cp -r ./kafka $DESTDIR/usr/share/kcompose/kafka
chmod +x $DESTDIR/usr/share/kcompose/kcompose.sh
ln -sT /usr/share/kcompose/kcompose.sh $DESTDIR/usr/bin/kcompose
