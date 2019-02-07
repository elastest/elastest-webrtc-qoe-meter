#!/bin/sh

FPS=24
PRESENTER=presenter.webm
VIEWER=viewer.webm
TMP_PRESENTER=p.webm
TMP_VIEWER=v.webm
CUT_PRESENTER=p-cut.webm
CUT_VIEWER=v-cut.webm
YUV_PRESENTER=p.yuv
YUV_VIEWER=v.yuv
TARGET_FODLER_YUV=.


# 1. Copying presenter and viewer files to current folder
if [ ! -f ../$PRESENTER ]; then
    echo ../$PRESENTER does not exist
    exit 1
fi
if [ ! -f ../$VIEWER ]; then
    echo ../$VIEWER does not exist
    exit 1
fi
if [ ! -f $PRESENTER ]; then
    echo Copying $PRESENTER
    cp ../$PRESENTER .
fi
if [ ! -f $VIEWER ]; then
    echo Copying $VIEWER
    cp ../$VIEWER .
fi

# 2. Remux presenter and viewer with a fixed bitrate
if [ ! -f $TMP_PRESENTER ]; then
    echo Remuxing presenter
    ffmpeg -y -r $FPS -i $PRESENTER $TMP_PRESENTER
fi
#mediainfo $TMP_PRESENTER
if [ ! -f $TMP_VIEWER ]; then
    echo Remuxing viewer
    ffmpeg -y -r $FPS -i $PRESENTER $TMP_VIEWER
fi
#mediainfo $TMP_VIEWER


# 3. Trim presenter and viewer (remove paddings)
# Extract images per frame (to find out change from padding to video and viceversa)
#ffmpeg -i $TMP_PRESENTER p_%04d.jpg
CUT_PRESENTER_FRAME_FROM=29
CUT_PRESENTER_FRAME_TO=211
CUT_PRESENTER_TIME_FROM=$(jq -n $CUT_PRESENTER_FRAME_FROM/$FPS)
CUT_PRESENTER_TIME_TO=$(jq -n $CUT_PRESENTER_FRAME_TO/$FPS)
CUT_PRESENTER_TIME=$(jq -n $CUT_PRESENTER_TIME_TO-$CUT_PRESENTER_TIME_FROM)

if [ ! -f $CUT_PRESENTER ]; then
    echo Cutting presentr
    ffmpeg -i $TMP_PRESENTER -ss 00:00:0$CUT_PRESENTER_TIME_FROM -t 00:00:0$CUT_PRESENTER_TIME -c:v libvpx -c:a libvorbis -y $CUT_PRESENTER
fi
#mediainfo $CUT_PRESENTER


#ffmpeg -i $TMP_VIEWER v_%04d.jpg
CUT_VIEWER_FRAME_FROM=29
CUT_VIEWER_FRAME_TO=211
CUT_VIEWER_TIME_FROM=$(jq -n $CUT_VIEWER_FRAME_FROM/$FPS)
CUT_VIEWER_TIME_TO=$(jq -n $CUT_VIEWER_FRAME_TO/$FPS)
CUT_VIEWER_TIME=$(jq -n $CUT_VIEWER_TIME_TO-$CUT_VIEWER_TIME_FROM)

if [ ! -f $CUT_VIEWER ]; then
    echo Cutting presentr
    ffmpeg -i $TMP_VIEWER -ss 00:00:0$CUT_VIEWER_TIME_FROM -t 00:00:0$CUT_VIEWER_TIME -c:v libvpx -c:a libvorbis -y $CUT_VIEWER
fi
#mediainfo $CUT_VIEWER

# 4. Convert videos to yuv420p
ffmpeg -i $CUT_PRESENTER -pix_fmt yuv420p -c:v rawvideo -an -y $TARGET_FODLER_YUV/$YUV_PRESENTER
ffmpeg -i $CUT_VIEWER -pix_fmt yuv420p -c:v rawvideo -an -y $TARGET_FODLER_YUV/$YUV_VIEWER

