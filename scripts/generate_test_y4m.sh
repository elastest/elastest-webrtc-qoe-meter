#!/bin/sh

VIDEO_SAMPLE_NAME=e-dv548_lwe08_christa_casebeer_003.mp4
VIDEO_SAMPLE_URL=https://archive.org/download/e-dv548_lwe08_christa_casebeer_003.ogg/$VIDEO_SAMPLE_NAME
VIDEO_DURATION=00:01:00
PADDING_DURATION_SEC=5

# 1. Download video sample from  https://archive.org/details/e-dv548_lwe08_christa_casebeer_003.ogg

if [ ! -f $VIDEO_SAMPLE_NAME ]; then
    echo $VIDEO_SAMPLE_NAME not exits ... downloading
    wget $VIDEO_SAMPLE_URL
else
    echo $VIDEO_SAMPLE_NAME already exits
fi

# 2. Cut original video
ffmpeg -i e-dv548_lwe08_christa_casebeer_003.mp4 -ss 00:00:00 -t $VIDEO_DURATION -c copy tmp.mp4

# 3. Create padding video based on a test pattern
ffmpeg -f lavfi -i testsrc=duration=$PADDING_DURATION_SEC:size=540x360:rate=29.970 padding.mp4

# 4. Concat final video
ffmpeg -i padding.mp4 -i tmp.mp4 -i padding.mp4 -filter_complex concat=n=3 test.mp4

# 5. Convert video to Y4M
ffmpeg -i test.mp4 -pix_fmt yuv420p test.y4m

# 6. Delete temporal video files and move result to root (test is going to look for the file there)
rm tmp.mp4 padding.mp4 test.mp4
mv test.y4m ..

