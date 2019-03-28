#!/bin/bash

FPS=24
PREFFIX=30
PRESENTER=$PREFFIX-presenter.webm
VIEWER=$PREFFIX-viewer.webm
TMP_PRESENTER=$PREFFIX-p.webm
TMP_VIEWER=$PREFFIX-v.webm
CUT_PRESENTER=$PREFFIX-p-cut.webm
CUT_VIEWER=$PREFFIX-v-cut.webm
YUV_PRESENTER=$PREFFIX-p.yuv
YUV_VIEWER=$PREFFIX-v.yuv
JPG_FOLDER=jpg
SOURCE_FOLDER=.

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


# 1. Copying presenter and viewer files to current folder
if [ ! -f $SOURCE_FOLDER/$PRESENTER ]; then
    echo $SOURCE_FOLDER/$PRESENTER does not exist
    exit 1
fi
if [ ! -f $SOURCE_FOLDER/$VIEWER ]; then
    echo $SOURCE_FOLDER/$VIEWER does not exist
    exit 1
fi
if [ ! -f $PRESENTER ]; then
    echo Copying $PRESENTER
    cp $SOURCE_FOLDER/$PRESENTER .
fi
if [ ! -f $VIEWER ]; then
    echo Copying $VIEWER
    cp $SOURCE_FOLDER/$VIEWER .
fi

# 2. Remux presenter and viewer with a fixed bitrate
if [ ! -f $TMP_PRESENTER ]; then
    echo Remuxing presenter
    ffmpeg -y -r $FPS -i $PRESENTER $TMP_PRESENTER
fi
#mediainfo $TMP_PRESENTER
if [ ! -f $TMP_VIEWER ]; then
    echo Remuxing viewer
    ffmpeg -y -r $FPS -i $VIEWER $TMP_VIEWER
fi
#mediainfo $TMP_VIEWER


# 3. Trim presenter and viewer (remove paddings)
# Extract images per frame (to find out change from padding to video and viceversa)

# Uncomment this line to find out frames (from, to) and stop script
#ffmpeg -i $TMP_PRESENTER $SOURCE_FOLDER/$JPG_FOLDER/p_%04d.jpg && exit 0

CUT_PRESENTER_FRAME_FROM=146
CUT_PRESENTER_FRAME_TO=1938
CUT_PRESENTER_TIME_FROM=$(jq -n $CUT_PRESENTER_FRAME_FROM/$FPS)
CUT_PRESENTER_TIME_TO=$(jq -n $CUT_PRESENTER_FRAME_TO/$FPS)
CUT_PRESENTER_TIME=$(jq -n $CUT_PRESENTER_TIME_TO-$CUT_PRESENTER_TIME_FROM)

if [ ! -f $CUT_PRESENTER ]; then
    echo Cutting presentr
    duration $CUT_PRESENTER_TIME_FROM
    from=$retval
    duration $CUT_PRESENTER_TIME
    to=$retval
    ffmpeg -i $TMP_PRESENTER -ss $from -t $to -c:v libvpx -c:a libvorbis -y $CUT_PRESENTER
fi
#mediainfo $CUT_PRESENTER

# Uncomment this line to find out frames (from, to) and stop script
#ffmpeg -i $TMP_VIEWER $SOURCE_FOLDER/$JPG_FOLDER/v_%04d.jpg && exit 0

CUT_VIEWER_FRAME_FROM=67
CUT_VIEWER_FRAME_TO=1164
CUT_VIEWER_TIME_FROM=$(jq -n $CUT_VIEWER_FRAME_FROM/$FPS)
CUT_VIEWER_TIME_TO=$(jq -n $CUT_VIEWER_FRAME_TO/$FPS)
CUT_VIEWER_TIME=$(jq -n $CUT_VIEWER_TIME_TO-$CUT_VIEWER_TIME_FROM)

if [ ! -f $CUT_VIEWER ]; then
    echo Cutting presentr
    duration $CUT_VIEWER_TIME_FROM
    from=$retval
    duration $CUT_VIEWER_TIME
    to=$retval
    ffmpeg -i $TMP_VIEWER -ss $from -t $to -c:v libvpx -c:a libvorbis -y $CUT_VIEWER
fi
#mediainfo $CUT_VIEWER

# 4. Convert videos to yuv420p
if [ ! -f $YUV_PRESENTER ]; then
	ffmpeg -i $CUT_PRESENTER -pix_fmt yuv420p -c:v rawvideo -an -y $YUV_PRESENTER
fi

if [ ! -f $YUV_VIEWER ]; then
	ffmpeg -i $CUT_VIEWER -pix_fmt yuv420p -c:v rawvideo -an -y $YUV_VIEWER
fi

# 5. Run VMAF
echo "Run VMAF with the following command:"
echo ./run_vmaf yuv420p 540 360 "$PWD"/"$YUV_PRESENTER" "$PWD"/"$YUV_VIEWER" --out-fmt json ">" "$PWD"/"$PREFFIX"-vmaf.json

