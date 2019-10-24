#!/bin/bash

DEFAULT_PREFIX=0
PREFIX=${1:-$DEFAULT_PREFIX}

DEFAULT_WIDTH=640
WIDTH=${2:-$DEFAULT_WIDTH}

DEFAULT_HEIGHT=480
HEIGHT=${3:-$DEFAULT_HEIGHT}

SOURCE_FOLDER=..
FPS=24
AUDIO_SAMPLE_RATE=16000
VIDEO_BITRATE=3M
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
WAV_PRESENTER=$PREFIX-p.wav
WAV_VIEWER=$PREFIX-v.wav
P_TMP_1=tmp_p_1.mkv
P_TMP_2=tmp_p_2.mkv
P_TMP_3=tmp_p_3.mkv
V_TMP_1=tmp_v_1.mkv
V_TMP_2=tmp_v_2.mkv
V_TMP_3=tmp_v_3.mkv
JPG_FOLDER=jpg
FFMPEG_LOG="-loglevel error"
CALCULATE_AUDIO_QOE=false
EXTRA_ALIGNMENT=false
P_SUFFIX="-p.jpg"
V_SUFFIX="-v.jpg"
VIDEO_LENGTH_SEC=35
YUV_PROFILE=yuv420p
FFMPEG_OPTIONS="-c:v libvpx -quality best -cpu-used 0 -b:v $VIDEO_BITRATE -pix_fmt $YUV_PROFILE"
CLEANUP=true

cleanup() {
    echo "Removing temporal files"
    rm -rf $JPG_FOLDER \
        ${PREFIX}_vmaf.json \
        $REMUXED_PRESENTER $REMUXED_VIEWER \
        $TMP_PRESENTER $TMP_VIEWER \
        $YUV_PRESENTER $YUV_VIEWER \
        $WAV_PRESENTER $WAV_VIEWER resampled_$WAV_PRESENTER resampled_$WAV_VIEWER \
        $PRESENTER $VIEWER \
        $CUT_PRESENTER $CUT_VIEWER \
        $P_TMP_1 $P_TMP_2 $P_TMP_3 $V_TMP_1 $V_TMP_2 $V_TMP_3
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

####################################################################################
####################################################################################

echo "*** Calculating QoE metrics (WebRTC $PREFIX% packet loss) ***"

# 0. Optional cleanup
if [ "$WIDTH" == "clean" ]; then
    cleanup
    exit 0
fi
if [ "$WIDTH" == "clean-all" ]; then
    cleanup
    rm $PREFIX_*.csv $PREFIX_*.txt 2>/dev/null
    exit 0
fi

# 1. Check VMAF and VQMT path
if [ -z "$VMAF_PATH" ]; then
    echo "You need to provide the path to VMAF binaries (check out from https://github.com/Netflix/vmaf) in the environmental variable VMAF_PATH"
    exit 1
fi
if [ -z "$VQMT_PATH" ]; then
    echo "You need to provide the path to VQMT binaries (check out from https://github.com/Rolinh/VQMT) in the environmental variable VQMT_PATH"
    exit 1
fi

# 2. Check presenter and viewer files and copying to current folder if not exist
if [ ! -f $PRESENTER ]; then
    if [ ! -f $SOURCE_FOLDER/$PRESENTER ]; then
        echo $SOURCE_FOLDER/$PRESENTER does not exist
        exit 1
    fi
    echo Copying presenter to current folder
    cp $SOURCE_FOLDER/$PRESENTER .
fi
if [ ! -f $VIEWER ]; then
    if [ ! -f $SOURCE_FOLDER/$VIEWER ]; then
        echo $SOURCE_FOLDER/$VIEWER does not exist
        exit 1
    fi
    echo Copying viewer to current folder
    cp $SOURCE_FOLDER/$VIEWER .
fi

# 3. Remux presenter and viewer with a fixed bitrate
if [ ! -f $TMP_PRESENTER ]; then
    echo Remuxing presenter
    ffmpeg $FFMPEG_LOG -y -i $PRESENTER -s ${WIDTH}x${HEIGHT} $FFMPEG_OPTIONS $REMUXED_PRESENTER
    ffmpeg $FFMPEG_LOG -y -i $REMUXED_PRESENTER -filter:v "minterpolate='mi_mode=dup:fps=$FPS'" $TMP_PRESENTER
fi
if [ ! -f $TMP_VIEWER ]; then
    echo  Remuxing viewer
    ffmpeg $FFMPEG_LOG -y -i $VIEWER -s ${WIDTH}x${HEIGHT} $FFMPEG_OPTIONS $REMUXED_VIEWER
    ffmpeg $FFMPEG_LOG -y -i $REMUXED_VIEWER -filter:v "minterpolate='mi_mode=dup:fps=$FPS'" $TMP_VIEWER
fi

# 3. Trim presenter and viewer (remove paddings)
# Extract images per frame (to find out change from padding to video and viceversa)

mkdir -p $JPG_FOLDER

if [ ! -f $CUT_PRESENTER ]; then
    ffmpeg $FFMPEG_LOG -i $TMP_PRESENTER $JPG_FOLDER/%04d$P_SUFFIX
    jpgs=("$JPG_FOLDER/*$P_SUFFIX")
    i_jpgs=$(ls -r $jpgs)

    echo "Checking padding in presenter video"
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

    echo "Cutting presenter from frame $CUT_PRESENTER_FRAME_FROM to $CUT_PRESENTER_FRAME_TO"

    CUT_PRESENTER_TIME_FROM=$(jq -n $CUT_PRESENTER_FRAME_FROM/$FPS)
    CUT_PRESENTER_TIME_TO=$(jq -n $CUT_PRESENTER_FRAME_TO/$FPS)
    CUT_PRESENTER_TIME=$(jq -n $CUT_PRESENTER_TIME_TO-$CUT_PRESENTER_TIME_FROM)

    duration $CUT_PRESENTER_TIME_FROM
    from=$retval
    duration $CUT_PRESENTER_TIME
    to=$retval
    ffmpeg $FFMPEG_LOG -i $TMP_PRESENTER -ss $from -t $to $FFMPEG_OPTIONS -y $CUT_PRESENTER
fi


if [ ! -f $CUT_VIEWER ]; then
    ffmpeg $FFMPEG_LOG -i $TMP_VIEWER $JPG_FOLDER/%04d$V_SUFFIX
    jpgs=("$JPG_FOLDER/*$V_SUFFIX")
    i_jpgs=$(ls -r $jpgs)

    echo "Checking padding in viewer video"
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

    echo "Cutting viewer from frame $CUT_VIEWER_FRAME_FROM to $CUT_VIEWER_FRAME_TO"

    CUT_VIEWER_TIME_FROM=$(jq -n $CUT_VIEWER_FRAME_FROM/$FPS)
    CUT_VIEWER_TIME_TO=$(jq -n $CUT_VIEWER_FRAME_TO/$FPS)
    CUT_VIEWER_TIME=$(jq -n $CUT_VIEWER_TIME_TO-$CUT_VIEWER_TIME_FROM)

    duration $CUT_VIEWER_TIME_FROM
    from=$retval
    duration $CUT_VIEWER_TIME
    to=$retval
    ffmpeg $FFMPEG_LOG -i $TMP_VIEWER -ss $from -t $to $FFMPEG_OPTIONS -y $CUT_VIEWER
fi


# 5. Extract audio to wav
if $CALCULATE_AUDIO_QOE || $EXTRA_ALIGNMENT && [ ! -f $WAV_PRESENTER ]; then
    echo "Extracting WAV from presenter"
    ffmpeg $FFMPEG_LOG -y -i $CUT_PRESENTER $WAV_PRESENTER
    ffmpeg $FFMPEG_LOG -y -i $CUT_PRESENTER -ar $AUDIO_SAMPLE_RATE resampled_$WAV_PRESENTER
fi

if $CALCULATE_AUDIO_QOE || $EXTRA_ALIGNMENT && [ ! -f $WAV_VIEWER ]; then
    echo "Extracting WAV from viewer"
    ffmpeg $FFMPEG_LOG -y -i $CUT_VIEWER $WAV_VIEWER
    ffmpeg $FFMPEG_LOG -y -i $CUT_VIEWER -ar $AUDIO_SAMPLE_RATE resampled_$WAV_VIEWER
fi


# 6. Optional fine-grained alignment

if $EXTRA_ALIGNMENT && [ ! -f $P_TMP_3 ]; then
    echo Fine-grained alignment in presenter

    rm $JPG_FOLDER/*.*
    ffmpeg $FFMPEG_LOG -i $CUT_PRESENTER $JPG_FOLDER/%04d$P_SUFFIX

    NUM_FRAMES_PRESENTER=$(ls -1q $JPG_FOLDER/*$P_SUFFIX | wc -l)
    FRAME_RATE_PRESENTER=$(jq -n $NUM_FRAMES_PRESENTER/$VIDEO_LENGTH_SEC)

    ffmpeg $FFMPEG_LOG -y -framerate $FRAME_RATE_PRESENTER -f image2 -i $JPG_FOLDER/%04d$P_SUFFIX -codec copy $P_TMP_1
    ffmpeg $FFMPEG_LOG -y -i $P_TMP_1 -i $WAV_PRESENTER -c copy -map 0:v:0 -map 1:a:0 $P_TMP_2
    ffmpeg $FFMPEG_LOG -y -i $P_TMP_2 -filter:v "fps='fps=$FPS'" $P_TMP_3
else
    P_TMP_3=$CUT_PRESENTER
fi

if $EXTRA_ALIGNMENT && [ ! -f $V_TMP_3 ]; then
    echo Fine-grained alignment in viewer

    rm $JPG_FOLDER/*.*
    ffmpeg $FFMPEG_LOG -i $CUT_VIEWER $JPG_FOLDER/%04d$V_SUFFIX

    NUM_FRAMES_VIEWER=$(ls -1q $JPG_FOLDER/*$V_SUFFIX | wc -l)
    FRAME_RATE_VIEWER=$(jq -n $NUM_FRAMES_VIEWER/$VIDEO_LENGTH_SEC)

    ffmpeg $FFMPEG_LOG -y -framerate $FRAME_RATE_VIEWER -f image2 -i $JPG_FOLDER/%04d$V_SUFFIX -codec copy $V_TMP_1
    ffmpeg $FFMPEG_LOG -y -i $V_TMP_1 -i $WAV_PRESENTER -c copy -map 0:v:0 -map 1:a:0 $V_TMP_2
    ffmpeg $FFMPEG_LOG -y -i $V_TMP_2 -filter:v "fps='fps=$FPS'" $V_TMP_3
else
    V_TMP_3=$CUT_VIEWER
fi

# 7. Convert videos to YUV_PROFILE
if [ ! -f $YUV_PRESENTER ]; then
    echo Converting presenter to $YUV_PROFILE
    ffmpeg $FFMPEG_LOG -i $P_TMP_3 -pix_fmt $YUV_PROFILE -c:v rawvideo -an -y $YUV_PRESENTER
fi

if [ ! -f $YUV_VIEWER ]; then
    echo Converting viewer to $YUV_PROFILE
    ffmpeg $FFMPEG_LOG -i $V_TMP_3 -pix_fmt $YUV_PROFILE -c:v rawvideo -an -y $YUV_VIEWER
fi


# 8. Run VMAF and VQMT
echo "Calculating VMAF"
$VMAF_PATH/run_vmaf yuv420p $WIDTH $HEIGHT $PWD/$YUV_PRESENTER $PWD/$YUV_VIEWER --out-fmt json > $PWD/${PREFIX}_vmaf.json && cat $PWD/$PREFIX_vmaf.json | jq '.frames[].VMAF_score' > $PWD/${PREFIX}_vmaf.csv

echo "Calculating VIFp, SSIM, MS-SSIM, PSNR, PSNR-HVS, and PSNR-HVS-M"
$VQMT_PATH/vqmt $PWD/$YUV_PRESENTER $PWD/$YUV_VIEWER $HEIGHT $WIDTH 1500 1 $PREFIX PSNR SSIM VIFP MSSSIM PSNRHVS PSNRHVSM >> /dev/null 2>&1

# 9. Run PESQ and ViSQOL
if $CALCULATE_AUDIO_QOE; then
    ORIG_PWD=$PWD

    if [ -z "$PESQ_PATH" ]; then
        echo "You need to provide the path to PESQ binaries (https://github.com/dennisguse/ITU-T_pesq) in the environmental variable PESQ_PATH"
    else
        echo "Calculating PESQ"
        cd $PESQ_PATH
        ./pesq +$AUDIO_SAMPLE_RATE $ORIG_PWD/resampled_$WAV_PRESENTER $ORIG_PWD/resampled_$WAV_VIEWER | tail -n 1 > $ORIG_PWD/${PREFIX}_pesq.txt
    fi

    if [ -z "$VISQOL_PATH" ]; then
        echo "You need to provide the path to ViSQOL binaries (https://sites.google.com/a/tcd.ie/sigmedia/) in the environmental variable VISQOL_PATH"
    else
        echo "Calculating ViSQOL"
        cd $VISQOL_PATH
        ./bazel-bin/visqol --reference_file $ORIG_PWD/$WAV_PRESENTER --degraded_file $ORIG_PWD/$WAV_VIEWER --verbose | grep MOS-LQO > $ORIG_PWD/${PREFIX}_visqol.txt
    fi

    cd $ORIG_PWD
fi

# 10. Cleanup
if $CLEANUP; then
    cleanup
fi

if $CALCULATE_AUDIO_QOE; then
    echo "*** Process finished OK. Check CSV results for video and TXT for audio at current folder ***"
else
    echo "*** Process finished OK. Check CSV results at current folder ***"
fi
