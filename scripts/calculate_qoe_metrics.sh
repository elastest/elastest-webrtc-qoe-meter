#!/bin/bash

##################################################################################
# DEFAULT VALUES
##################################################################################

PREFIX=0
WIDTH=640
HEIGHT=480
SOURCE_FOLDER=..
FPS=24
PESQ_AUDIO_SAMPLE_RATE=16000
VIDEO_BITRATE=3M
JPG_FOLDER=jpg
FFMPEG_LOG="-loglevel error"
P_SUFFIX="-p.jpg"
V_SUFFIX="-v.jpg"
VIDEO_LENGTH_SEC=30
YUV_PROFILE=yuv420p
FFMPEG_OPTIONS="-c:v libvpx -b:v $VIDEO_BITRATE -pix_fmt $YUV_PROFILE"
CALCULATE_AUDIO_QOE=false
CLEANUP=true
ALIGN_OCR=false
USAGE="Usage: `basename $0` [-p=prefix] [-w=width] [-h=height] [--calculate_audio_qoe] [--no_cleanup] [--clean] [-vr=video_ref] [-ar=audio_ref] [--align_ocr] [--use_default_ref]"

##################################################################################
# FUNCTIONS
##################################################################################

init() {
   mkdir -p $JPG_FOLDER

   PRESENTER=$PREFIX-presenter.webm
   VIEWER=$PREFIX-viewer.webm
   REMUXED_PRESENTER=$PREFIX-remux-p.webm
   REMUXED_VIEWER=$PREFIX-remux-v.webm
   TMP_PRESENTER=$PREFIX-p.webm
   TMP_VIEWER=$PREFIX-v.webm
   CUT_PRESENTER=$PREFIX-p-cut.webm
   CUT_VIEWER=$PREFIX-v-cut.webm
   OCR_PRESENTER=$PREFIX-p-ocr.webm
   OCR_VIEWER=$PREFIX-v-ocr.webm
   YUV_PRESENTER=$PREFIX-p.yuv
   YUV_VIEWER=$PREFIX-v.yuv
   WAV_PRESENTER=$PREFIX-p.wav
   WAV_VIEWER=$PREFIX-v.wav
}

cleanup() {
   echo "Removing temporal files"
   rm -rf $JPG_FOLDER \
       ${PREFIX}_vmaf.json \
       $REMUXED_PRESENTER $REMUXED_VIEWER \
       $TMP_PRESENTER $TMP_VIEWER \
       $YUV_PRESENTER $YUV_VIEWER \
       $WAV_PRESENTER $WAV_VIEWER resampled_$WAV_PRESENTER resampled_$WAV_VIEWER resampled_ref.wav \
       $PRESENTER $VIEWER \
       $CUT_PRESENTER $CUT_VIEWER \
       $OCR_PRESENTER $OCR_VIEWER
}

duration() {
   num=$1
   decimals=

   strindex $1 .
   if [ $retval -gt 0 ]; then
      num=$(echo $1 | cut -d'.' -f 1)
      decimals=$(echo $1 | cut -d'.' -f 2)
   fi

   ((h=num/3600))
   ((m=num%3600/60))
   ((s=num%60))

   retval=$(printf "%02d:%02d:%02d\n" $h $m $s)

   if [ ! -z "$decimals" ]; then
      retval="${retval}.${decimals}"
   fi
}

strindex() {
   x="${1%%$2*}"
   retval=$([[ "$x" = "$1" ]] && echo -1 || echo "${#x}")
}

find_index() {
   x="${1%%$2*}"
   retval=${#x}
}

get_r() {
   input=$1
   find_index $input "$rgb("
   i=$retval
   str=${input:i}
   find_index $str ","
   j=$retval
   retval=$(echo $str | cut -c2-$j)
}


get_g() {
   input=$1
   find_index $input ","
   i=$(($retval + 1))
   str=${input:i}
   find_index $str ","
   j=$retval
   retval=$(echo $str | cut -c1-$j)
}

get_b() {
   input=$1
   find_index $input ","
   i=$(($retval + 1))
   str=${input:i}
   find_index $str ","
   i=$(($retval + 1))
   str=${str:i}
   find_index $str ","
   j=$(($retval - 1))
   retval=$(echo $str | cut -c1-$j)
}

get_rgb() {
   image=$1
   width=$2
   height=$3

   retval=$(convert $image -format "%[pixel:u.p{$width,$height}]" -colorspace rgb info:)
}

match_threshold() {
   input=$1
   expected=$2
   threshold=$3
   diff=$((input-expected))
   absdiff=${diff#-}

   #echo "$input==$expected -> $absdiff<=$threshold"

   if [ "$absdiff" -le "$threshold" ]; then
      retval=true
   else
      retval=false
   fi
}

match_rgb() {
   r=$1
   g=$2
   b=$3
   exp_r=$4
   exp_g=$5
   exp_b=$6

   match_threshold $r $exp_r $threshold
   match_r=$retval
   match_threshold $g $exp_g $threshold
   match_g=$retval
   match_threshold $b $exp_b $threshold
   match_b=$retval

   #echo "$r==$exp_r->$match_r $g==$exp_g->$match_g $b==$exp_b->$match_b"

   if $match_r && $match_g && $match_b; then
      retval=true
   else
      retval=false
   fi
}

match_color() {
   image=$1
   width=$2
   height=$3
   threshold=$4
   expected_r=$5
   expected_g=$6
   expected_b=$7

   #echo "match_color($1): $2,$3 -- $5 $6 $7"

   get_rgb $image $width $height
   color=$retval
   get_r "$color"
   r=$retval
   get_g "$color"
   g=$retval
   get_b "$color"
   b=$retval

   match_rgb $r $g $b $expected_r $expected_g $expected_b
}

# Expected values for lavfi padding video: width,height rgb(r,g,b) [color]:
# 120,240 rgb(0,255,255)  [cyan]
# 200,240 rgb(255,0,253) [purple]
# 280,240 rgb(0,0,253) [blue]
# 360,240 rgb(253,255,0) [yellow]
# 420,240 rgb(0,255,0) [green]
# 500,240 rgb(253,0,0) [red]
match_image() {
   image=$1
   threshold=50

   height=$(($HEIGHT / 3))
   bar=$(($WIDTH / 8))
   halfbar=$(($bar / 2))

   cyan=$((halfbar + ($bar * 1)))
   purple=$((halfbar + ($bar * 2)))
   blue=$((halfbar + ($bar * 3)))
   yellow=$((halfbar + ($bar * 4)))
   green=$((halfbar + ($bar * 5)))
   red=$((halfbar + ($bar * 6)))

   match_color $image $cyan $height $threshold 0 255 255
   match_cyan=$retval
   match_color $image $purple $height $threshold 255 0 255
   match_purple=$retval
   match_color $image $blue $height $threshold 0 0 255
   match_blue=$retval
   match_color $image $yellow $height $threshold 255 255 0
   match_yellow=$retval
   match_color $image $green $height $threshold 0 255 0
   match_green=$retval
   match_color $image $red $height $threshold 255 0 0
   match_red=$retval

   if $match_cyan && $match_purple && $match_blue && $match_yellow && $match_red; then
      retval=true
   else
      retval=false
   fi
}

check_input() {
   input=$1

   if [ ! -f $SOURCE_FOLDER/$input ]; then
       echo "$SOURCE_FOLDER/$input does not exist"
       exit 1
   fi
   echo "Copying $input to current folder"
   cp $SOURCE_FOLDER/$input .
}

remux() {
   input=$1
   output1=$2
   output2=$3

   echo "Remuxing $input to $output2"
   ffmpeg $FFMPEG_LOG -y -i $input -s ${WIDTH}x${HEIGHT} $FFMPEG_OPTIONS $output1
   ffmpeg $FFMPEG_LOG -y -i $output1 -filter:v "minterpolate='mi_mode=dup:fps=$FPS'" $output2
}

cut_video() {
   input_cut=$1
   output_cut=$2
   suffix_cut=$3

   echo "Checking padding in $input_cut (result: $output_cut)"

   # Extract images per frame (to find out change from padding to video and viceversa)
   ffmpeg $FFMPEG_LOG -i $input_cut $JPG_FOLDER/%04d$suffix_cut
   jpgs=("$JPG_FOLDER/*$suffix_cut")
   i_jpgs=$(ls -r $jpgs)

   for i in $jpgs; do
      file=$(echo $i)
      match_image "$file"
      match=$retval
      if ! $match; then
         cut_frame_from=$(echo "$file" | tr -dc '0-9')
         break
      fi
   done

   for i in $i_jpgs; do
       file=$(echo $i)
       match_image "$file"
       match=$retval
       if ! $match; then
         cut_frame_to=$(echo "$file" | tr -dc '0-9')
         break
       fi
   done

   echo "Cutting $1 from frame $cut_frame_from to $cut_frame_to"

   cut_time_from=$(jq -n $cut_frame_from/$FPS)
   cut_time_to=$(jq -n $cut_frame_to/$FPS)
   cut_time=$(jq -n $cut_time_to-$cut_time_from)

   duration $cut_time_from
   from=$retval
   duration $cut_time
   to=$retval
   ffmpeg $FFMPEG_LOG -y -i $input_cut -ss $from -t $to $FFMPEG_OPTIONS $output_cut
}

extract_wav() {
   input=$1
   output=$2

   echo "Extracting $output from $input"
   ffmpeg $FFMPEG_LOG -y -i $input $output

   echo "Resampling audio for PESQ analysis ($PESQ_AUDIO_SAMPLE_RATE Hz)"
   ffmpeg $FFMPEG_LOG -y -i $input -ar $PESQ_AUDIO_SAMPLE_RATE resampled_$output
   ffmpeg $FFMPEG_LOG -y -i $AUDIO_REF -ar $PESQ_AUDIO_SAMPLE_RATE resampled_ref.wav
}

convert_yuv() {
   input=$1
   output=$2

   echo "Converting $input to $output ($YUV_PROFILE profile)"
   ffmpeg $FFMPEG_LOG -i $input -pix_fmt $YUV_PROFILE -c:v rawvideo -an -y $output
}

check_number() {
   re='^[0-9]+$'
   input=$1

   if [ -n "$input" ] && [ "$input" -eq "$input" ] 2>/dev/null; then
      retval=true
   else
      retval=false
   fi
}

align_ocr() {
   video_ocr=$1
   output_ocr=$2
   wav_ocr=$3

   echo "Aligning $video_ocr based on frame OCR recognition"

   cut_folder=$JPG_FOLDER/cut
   mkdir -p $cut_folder
   rm -f $JPG_FOLDER/*.jpg
   rm -f $cut_folder/*.jpg

   ffmpeg $FFMPEG_LOG -i $video_ocr -qscale:v 2 $JPG_FOLDER/%04d.jpg

   next=$(($VIDEO_LENGTH_SEC * $FPS))
   skipped=0
   ocr_errors=0
   files=($JPG_FOLDER/*.jpg)
   for ((i=${#files[@]}-1; i>=0; i--)); do
      f=${files[$i]}
      filename=$(basename $f)

      crop_value=100x45+270+430
      if [ $WIDTH -eq 1280 ] && [ $HEIGHT -eq 720 ]; then
         crop_value=100x45+590+670
      fi
      convert $f -crop $crop_value $cut_folder/_$filename

      #frame=$(tesseract $cut_folder/_$filename stdout --psm 7 digits 2>/dev/null | sed -r '/^\s*$/d')
      frame=$(gocr -C 0-9 $cut_folder/_$filename | tr -d '[:space:]')
      rm $cut_folder/_$filename

      check_number $frame
      is_number=$retval

      if $is_number; then
         #echo "$filename = $frame"
         j=$frame
         while [ $j -le $next ];do
            output=$(printf "%04d\n" $j)
            cp $f $cut_folder/${output}.jpg
            if [ $j -ne $next ]; then
               skipped=$(($skipped+1))
            fi
            j=$(($j+1))
         done
         next=$(($frame-1))
      else
         #echo "Skipping $filename (recognized: $frame)"
         ocr_errors=$(($ocr_errors+1))
      fi
   done
   i=1
   while [ $i -le $next ]; do
      output=$(printf "%04d\n" $i)
      cp $f $cut_folder/${output}.jpg
      i=$(($i+1))
   done

   echo "Number of frames skipped in $output_ocr: $skipped"
   echo "Number of frames not recognized by OCR in $output_ocr: $ocr_errors"

   if $CALCULATE_AUDIO_QOE; then
      ffmpeg $FFMPEG_LOG -y -framerate $FPS -f image2 -i $cut_folder/%04d.jpg -i $wav_ocr $output_ocr
   else
      ffmpeg $FFMPEG_LOG -y -framerate $FPS -f image2 -i $cut_folder/%04d.jpg $output_ocr
   fi
}


##################################################################################
# PARSE ARGUMENTS
##################################################################################

for i in "$@"; do
   case $i in
      --use_default_ref)
      VIDEO_REF="../test-no-padding.yuv"
      AUDIO_REF="../test-no-padding.wav"
      CALCULATE_AUDIO_QOE=true
      shift
      ;;
      -vr=*|--video_ref=*)
      VIDEO_REF="${i#*=}"
      shift
      ;;
      -ar=*|--audio_ref=*)
      AUDIO_REF="${i#*=}"
      shift
      ;;
      -p=*|--prefix=*)
      PREFIX="${i#*=}"
      shift
      ;;
      -w=*|--width=*)
      WIDTH="${i#*=}"
      shift
      ;;
      -h=*|--height=*)
      HEIGHT="${i#*=}"
      shift
      ;;
      --calculate_audio_qoe)
      CALCULATE_AUDIO_QOE=true
      shift
      ;;
      --align_ocr)
      ALIGN_OCR=true
      shift
      ;;
      --no_cleanup)
      CLEANUP=false
      shift
      ;;
      --clean)
      init
      cleanup
      rm $PREFIX_*.csv $PREFIX_*.txt 2>/dev/null
      exit 0
      shift
      ;;
      *) # unknown option
      echo "$USAGE"
      exit 0
      ;;
  esac
done

##################################################################################
# INIT SCRIPT
##################################################################################

echo "*** Calculating QoE metrics ***"

######################################
# 1. Check VMAF and VQMT path and init
######################################
if [ -z "$VMAF_PATH" ]; then
   echo "You need to provide the path to VMAF binaries (check out from https://github.com/Netflix/vmaf) in the environmental variable VMAF_PATH"
   exit 1
fi
if [ -z "$VQMT_PATH" ]; then
   echo "You need to provide the path to VQMT binaries (check out from https://github.com/Rolinh/VQMT) in the environmental variable VQMT_PATH"
   exit 1
fi
init

#####################################
# 2. Check presenter and viewer files
#####################################
if [ -z "$VIDEO_REF" ] && [ ! -f $PRESENTER ]; then
   check_input $PRESENTER
fi
if [ ! -f $VIEWER ]; then
   check_input $VIEWER
fi

###################################################################
# 3. Remux presenter and viewer with a fixed bitrate and resolution
###################################################################
if [ -z "$VIDEO_REF" ] && [ ! -f $TMP_PRESENTER ]; then
   remux $PRESENTER $REMUXED_PRESENTER $TMP_PRESENTER
fi
if [ ! -f $TMP_VIEWER ]; then
   remux $VIEWER $REMUXED_VIEWER $TMP_VIEWER
fi

###############################################
# 4. Cut presenter and viewer (remove paddings)
###############################################
if [ -z "$VIDEO_REF" ] && [ ! -f $CUT_PRESENTER ]; then
   cut_video $TMP_PRESENTER $CUT_PRESENTER $P_SUFFIX
fi
if [ ! -f $CUT_VIEWER ]; then
   cut_video $TMP_VIEWER $CUT_VIEWER $V_SUFFIX
fi

#########################
# 5. Extract audio to WAV
#########################
if $CALCULATE_AUDIO_QOE && [ -z "$AUDIO_REF" ] && [ ! -f $WAV_PRESENTER ]; then
   extract_wav $CUT_PRESENTER $WAV_PRESENTER
fi
if $CALCULATE_AUDIO_QOE &&  [ ! -f $WAV_VIEWER ]; then
   extract_wav $CUT_VIEWER $WAV_VIEWER
fi


#######################################
# 6. Alignment based on OCR recognition
#######################################
if $ALIGN_OCR && [ -z "$VIDEO_REF" ]; then
   if [ ! -f $OCR_PRESENTER ]; then
      align_ocr $CUT_PRESENTER $OCR_PRESENTER $WAV_PRESENTER
   fi
   CUT_PRESENTER=$OCR_PRESENTER
fi
if $ALIGN_OCR; then
   if [ ! -f $OCR_VIEWER ]; then
      align_ocr $CUT_VIEWER $OCR_VIEWER $WAV_VIEWER
   fi
   CUT_VIEWER=$OCR_VIEWER
fi

#########################
# 7. Convert video to YUV
#########################
if [ -z "$VIDEO_REF" ] && [ ! -f $YUV_PRESENTER ]; then
   convert_yuv $CUT_PRESENTER $YUV_PRESENTER
fi
if [ ! -f $YUV_VIEWER ]; then
   convert_yuv $CUT_VIEWER $YUV_VIEWER
fi

######################
# 8. Run VMAF and VQMT
######################
REF=$YUV_PRESENTER
if [ ! -z "$VIDEO_REF" ]; then
    REF=$VIDEO_REF
fi

echo "Calculating VMAF"
$VMAF_PATH/run_vmaf yuv420p $WIDTH $HEIGHT $PWD/$REF $PWD/$YUV_VIEWER --out-fmt json > $PWD/${PREFIX}_vmaf.json && cat $PWD/${PREFIX}_vmaf.json | jq '.frames[].VMAF_score' > $PWD/${PREFIX}_vmaf.csv

echo "Calculating VIFp, SSIM, MS-SSIM, PSNR, PSNR-HVS, and PSNR-HVS-M"
$VQMT_PATH/vqmt $PWD/$REF $PWD/$YUV_VIEWER $HEIGHT $WIDTH 1500 1 $PREFIX PSNR SSIM VIFP MSSSIM PSNRHVS PSNRHVSM >> /dev/null 2>&1

########################
# 9. Run PESQ and ViSQOL
########################
if $CALCULATE_AUDIO_QOE; then
    ORIG_PWD=$PWD

    REF_PESQ=resampled_$WAV_PRESENTER
    REF_ViSQOL=$WAV_PRESENTER
    if [ ! -z "$AUDIO_REF" ]; then
        REF_PESQ=resampled_ref.wav
        REF_ViSQOL=$AUDIO_REF
    fi

    if [ -z "$PESQ_PATH" ]; then
        echo "You need to provide the path to PESQ binaries (https://github.com/dennisguse/ITU-T_pesq) in the environmental variable PESQ_PATH"
    else
        echo "Calculating PESQ"
        cd $PESQ_PATH
        ./pesq +$PESQ_AUDIO_SAMPLE_RATE $ORIG_PWD/$REF_PESQ $ORIG_PWD/resampled_$WAV_VIEWER | tail -n 1 > $ORIG_PWD/${PREFIX}_pesq.txt
    fi

    if [ -z "$VISQOL_PATH" ]; then
        echo "You need to provide the path to ViSQOL binaries (https://sites.google.com/a/tcd.ie/sigmedia/) in the environmental variable VISQOL_PATH"
    else
        echo "Calculating ViSQOL"
        cd $VISQOL_PATH
        ./bazel-bin/visqol --reference_file $ORIG_PWD/$REF_ViSQOL --degraded_file $ORIG_PWD/$WAV_VIEWER --verbose | grep MOS-LQO > $ORIG_PWD/${PREFIX}_visqol.txt
    fi

    cd $ORIG_PWD
fi

########################
# 10. Cleanup and finish
########################
if $CLEANUP; then
    cleanup
fi

if $CALCULATE_AUDIO_QOE; then
    echo "*** Process finished OK. Check CSV results for video and TXT for audio at current folder ***"
else
    echo "*** Process finished OK. Check CSV results at current folder ***"
fi
