#!/bin/sh

INPUT_FOLDER=frames-p
CUT_FOLDER=frames-p/cut

check_number() {
   re='^[0-9]+$'
   input=$1

   if [ -n "$input" ] && [ "$input" -eq "$input" ] 2>/dev/null; then
      retval=true
   else
      retval=false
   fi
}


last=0
for f in $INPUT_FOLDER/*.jpg ; do
   filename=$(basename $f)
   convert $f -crop 100x45+590+670 $CUT_FOLDER/$filename

   #frame=$(tesseract $CUT_FOLDER/$filename stdout --psm 7 digits 2>/dev/null | sed -r '/^\s*$/d')
   frame=$(gocr -C 0-9 $CUT_FOLDER/$filename)

   check_number $frame
   is_number=$retval

   if $is_number; then
      #echo $filename = $frame
      i=$(($last+1))
      while [ $i -le $frame ];do
         output=$(printf "%04d\n" $i)
         cp $f $CUT_FOLDER/${output}.jpg
         i=$(($i+1))
      done
      last=$frame
   else
      echo "Skipping $filename (recognized: $frame)"
   fi

   rm $CUT_FOLDER/$filename
done
