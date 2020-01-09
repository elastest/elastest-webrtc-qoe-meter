#!/bin/sh

# 1280x640
./calculate_qoe_metrics.sh -p=75jitter --width=1280 --height=720 --use_default_ref --align_ocr --no_cleanup
./calculate_qoe_metrics.sh -p=75jitter --width=1280 --height=720 --use_default_ref --only_vmaf --no_cleanup

# 640x480
./calculate_qoe_metrics.sh -p=75jitter --use_default_ref --align_ocr --no_cleanup
./calculate_qoe_metrics.sh -p=75jitter --use_default_ref --only_vmaf --no_cleanup
