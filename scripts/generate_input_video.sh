#!/bin/sh

VIDEO_SAMPLE_NAME=e-dv548_lwe08_christa_casebeer_003.mp4
VIDEO_SAMPLE_URL=https://archive.org/download/e-dv548_lwe08_christa_casebeer_003.ogg/$VIDEO_SAMPLE_NAME
VIDEO_DURATION=00:01:00
PADDING_DURATION_SEC=5
WIDTH=640
HEIGHT=480
FPS=24
FFMPEG_LOG="-loglevel panic"
TARGET_VIDEO=../test.y4m

# 1. Download video sample from  https://archive.org/details/e-dv548_lwe08_christa_casebeer_003.ogg

if [ ! -f $VIDEO_SAMPLE_NAME ]; then
    echo "Content video ($VIDEO_SAMPLE_NAME) not exits ... downloading"
    wget $VIDEO_SAMPLE_URL
else
    echo "Content video ($VIDEO_SAMPLE_NAME) already exits"
fi

# 2. Cut original video
echo "Cutting original video (duration $VIDEO_DURATION)"
ffmpeg $FFMPEG_LOG -i e-dv548_lwe08_christa_casebeer_003.mp4 -ss 00:00:00 -t $VIDEO_DURATION -vf scale="$WIDTH:$HEIGHT",setsar=1:1 -r $FPS tmp.mp4


# 3. Create padding video based on a test pattern
echo "Creating padding video ($PADDING_DURATION_SEC seconds)"
ffmpeg $FFMPEG_LOG -f lavfi -i testsrc=duration=$PADDING_DURATION_SEC:size="$WIDTH"x"$HEIGHT":rate=$FPS padding.mp4


# 4. Concatenate final video
echo "Concatenating padding and content videos"
ffmpeg $FFMPEG_LOG -i padding.mp4 -i tmp.mp4 -i padding.mp4 -filter_complex concat=n=3 test.mp4


# 5. Convert video to Y4M
echo "Converting video to Y4M ($TARGET_VIDEO)"
ffmpeg $FFMPEG_LOG -i test.mp4 -pix_fmt yuv420p $TARGET_VIDEO

# 6. Delete temporal video files
echo "Deleting temporal files"
rm tmp.mp4 padding.mp4 test.mp4
