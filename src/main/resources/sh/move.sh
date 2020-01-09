#!/bin/bash

FOLDER=$1
PREFIX=$2
TYPE=$3

if [[ -z "$FOLDER" || -z "$PREFIX" || -z "$TYPE" ]]; then
   echo "Usage: $0 folder prefix cut|ocr"
   exit 1
fi

if [ -d "$FOLDER" ]; then
   echo "$FOLDER already exists"
   exit 1
fi


mkdir $FOLDER
mv *.json *.csv *.txt $FOLDER 2>/dev/null
cp $PREFIX-presenter.webm $FOLDER 2>/dev/null
cp $PREFIX-viewer.webm $FOLDER 2>/dev/null

if [ "$TYPE" = "cut" ]; then
   cp $PREFIX-v-cut.webm $FOLDER 2>/dev/null
else
   cp $PREFIX-v-ocr.webm $FOLDER 2>/dev/null
fi

cp $PREFIX-v.wav $FOLDER/$FOLDER.wav 2>/dev/null

cp ../test-no-padding.wav $FOLDER 2>/dev/null

rm *.wav *.yuv
