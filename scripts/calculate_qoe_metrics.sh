#!/bin/bash

####################################################################################
# Fill these values with the binary path to VMAF and VQMT (compile from sources at
# https://github.com/Netflix/vmaf and https://github.com/Rolinh/VQMT)
####################################################################################
VMAF_PATH=
VQMT_PATH=
####################################################################################

DEFAULT_PREFIX=20
PREFIX=${1:-$DEFAULT_PREFIX}
SOURCE_FOLDER=..
FPS=24
PRESENTER=$PREFIX-presenter.webm
VIEWER=$PREFIX-viewer.webm
REMUXED_PRESENTER=$PREFIX-remux-p.webm
REMUXED_VIEWER=$PREFIX-remux-v.webm
TMP_PRESENTER=$PREFIX-p.webm
TMP_VIEWER=$PREFIX-v.webm
CUT_PRESENTER=$PREFIX-p-cut.webm
CUT_VIEWER=$PREFIX-v-cut.webm
YUV_PRESENTER=$PREFIX-p.yuv
YUV_VIEWER=$PREFIX-v.yuv
JPG_FOLDER=jpg
WIDTH=640
HEIGHT=480

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
# 60,240  rgb(255,255,255) [white]
# 120,240 rgb(0,255,255)  [cyan]
# 200,240 rgb(255,0,253) [purple]
# 280,240 rgb(0,0,253) [blue]
# 360,240 rgb(253,255,0) [yellow]
# 420,240 rgb(0,255,0) [green]
# 500,240 rgb(253,0,0) [red]
# 580,240 rgb(0,0,0) [black]
match_image() {
   image=$1
   threshold=50
   height=240

   match_color $image 60 $height $threshold 255 255 255
   match_white=$retval
   match_color $image 120 $height $threshold 0 255 255
   match_cyan=$retval
   match_color $image 200 $height $threshold 255 0 255
   match_purple=$retval
   match_color $image 280 $height $threshold 0 0 255
   match_blue=$retval
   match_color $image 360 $height $threshold 255 255 0
   match_yellow=$retval
   match_color $image 420 $height $threshold 0 255 0
   match_green=$retval
   match_color $image 500 $height $threshold 255 0 0
   match_red=$retval
   match_color $image 580 $height $threshold 0 0 0
   match_black=$retval

   if $match_black && $match_cyan && $match_purple && $match_blue && $match_yellow && $match_red && $match_black; then
      retval=true
   else
      retval=false
   fi
}

####################################################################################
####################################################################################

# 0. Check VMAF and VQMT path
if [ -z "$VMAF_PATH" ]; then
    echo "You need to provide the path to VMAF binaries (check out from https://github.com/Netflix/vmaf) in the variable VMAF_PATH"
    exit 1
fi
if [ -z "$VQMT_PATH" ]; then
    echo "You need to provide the path to VQMT binaries (check out from https://github.com/Rolinh/VQMT) in the variable VQMT_PATH"
    exit 1
fi

# 1. Check presenter and viewer files and copying to current folder if not exist
if [ ! -f $PRESENTER ]; then
    if [ ! -f $SOURCE_FOLDER/$PRESENTER ]; then
        echo $SOURCE_FOLDER/$PRESENTER does not exist
        exit 1
    fi
    echo Moving $PRESENTER
    mv $SOURCE_FOLDER/$PRESENTER .
fi
if [ ! -f $VIEWER ]; then
    if [ ! -f $SOURCE_FOLDER/$VIEWER ]; then
        echo $SOURCE_FOLDER/$VIEWER does not exist
        exit 1
    fi
    echo Moving $VIEWER
    mv $SOURCE_FOLDER/$VIEWER .
fi

# 2. Remux presenter and viewer with a fixed bitrate
if [ ! -f $TMP_PRESENTER ]; then
    echo Remuxing presenter
    ffmpeg -y -i $PRESENTER $REMUXED_PRESENTER
    ffmpeg -y -i $REMUXED_PRESENTER -filter:v "minterpolate='mi_mode=dup:fps=$FPS'" $TMP_PRESENTER
fi
if [ ! -f $TMP_VIEWER ]; then
    echo  Remuxing viewer
    ffmpeg -y -i $VIEWER $REMUXED_VIEWER
    ffmpeg -y -i $REMUXED_VIEWER -filter:v "minterpolate='mi_mode=dup:fps=$FPS'" $TMP_VIEWER
fi

# 3. Trim presenter and viewer (remove paddings)
# Extract images per frame (to find out change from padding to video and viceversa)

mkdir -p $JPG_FOLDER

if [ ! -f $CUT_PRESENTER ]; then
    p_suffix="-p.jpg"
    ffmpeg -i $TMP_PRESENTER $JPG_FOLDER/%04d$p_suffix
    jpgs=("$JPG_FOLDER/*$p_suffix")
    i_jpgs=$(ls -r $jpgs)

    echo "Checking padding in presenter video ... please wait"
    for i in $jpgs; do
        file=$(echo $i)
        match_image "$file"
        match=$retval
        if ! $match; then
           CUT_PRESENTER_FRAME_FROM=$(echo "$file" | tr -dc '0-9')
           break
        fi
    done

    for i in $i_jpgs; do
        file=$(echo $i)
        match_image "$file"
        match=$retval
        if ! $match; then
           CUT_PRESENTER_FRAME_TO=$(echo "$file" | tr -dc '0-9')
           break
        fi
    done

    echo "*** Cutting presenter from frame $CUT_PRESENTER_FRAME_FROM to $CUT_PRESENTER_FRAME_TO"

    CUT_PRESENTER_TIME_FROM=$(jq -n $CUT_PRESENTER_FRAME_FROM/$FPS)
    CUT_PRESENTER_TIME_TO=$(jq -n $CUT_PRESENTER_FRAME_TO/$FPS)
    CUT_PRESENTER_TIME=$(jq -n $CUT_PRESENTER_TIME_TO-$CUT_PRESENTER_TIME_FROM)

    duration $CUT_PRESENTER_TIME_FROM
    from=$retval
    duration $CUT_PRESENTER_TIME
    to=$retval
    ffmpeg -i $TMP_PRESENTER -ss $from -t $to -c:v libvpx -c:a libvorbis -y $CUT_PRESENTER
fi


if [ ! -f $CUT_VIEWER ]; then
    v_suffix="-v.jpg"
    ffmpeg -i $TMP_VIEWER $JPG_FOLDER/%04d$v_suffix
    jpgs=("$JPG_FOLDER/*$v_suffix")
    i_jpgs=$(ls -r $jpgs)

    echo "Checking padding in viewer video ... please wait"
    for i in $jpgs; do
        file=$(echo $i)
        match_image "$file"
        match=$retval
        if ! $match; then
           CUT_VIEWER_FRAME_FROM=$(echo "$file" | tr -dc '0-9')
           break
        fi
    done

    for i in $i_jpgs; do
        file=$(echo $i)
        match_image "$file"
        match=$retval
        if ! $match; then
           CUT_VIEWER_FRAME_TO=$(echo "$file" | tr -dc '0-9')
           break
        fi
    done

    echo "*** Cutting viewer from frame $CUT_VIEWER_FRAME_FROM to $CUT_VIEWER_FRAME_TO"

    CUT_VIEWER_TIME_FROM=$(jq -n $CUT_VIEWER_FRAME_FROM/$FPS)
    CUT_VIEWER_TIME_TO=$(jq -n $CUT_VIEWER_FRAME_TO/$FPS)
    CUT_VIEWER_TIME=$(jq -n $CUT_VIEWER_TIME_TO-$CUT_VIEWER_TIME_FROM)

    duration $CUT_VIEWER_TIME_FROM
    from=$retval
    duration $CUT_VIEWER_TIME
    to=$retval
    ffmpeg -i $TMP_VIEWER -ss $from -t $to -c:v libvpx -c:a libvorbis -y -max_muxing_queue_size 1024 $CUT_VIEWER
fi

# 4. Convert videos to yuv420p
if [ ! -f $YUV_PRESENTER ]; then
	ffmpeg -i $CUT_PRESENTER -pix_fmt yuv420p -c:v rawvideo -an -y $YUV_PRESENTER
fi

if [ ! -f $YUV_VIEWER ]; then
	ffmpeg -i $CUT_VIEWER -pix_fmt yuv420p -c:v rawvideo -an -y $YUV_VIEWER
fi

# 5. Run VMAF and VQMT
echo "Running VMAF ..."
$VMAF_PATH/run_vmaf yuv420p $WIDTH $HEIGHT $PWD/$YUV_PRESENTER $PWD/$YUV_VIEWER --out-fmt json > $PWD/$PREFIX-vmaf.json && cat $PWD/$PREFIX-vmaf.json | jq '.frames[].VMAF_score' > $PWD/$PREFIX-vmaf.csv

echo "Running VQMT ..."
$VQMT_PATH/vqmt $PWD/$YUV_PRESENTER $PWD/$YUV_VIEWER $HEIGHT $WIDTH 1500 1 $PREFIX PSNR SSIM VIFP MSSSIM PSNRHVS PSNRHVSM

echo "*** Post-process finished OK. Check CSV results at $PWD ***"
