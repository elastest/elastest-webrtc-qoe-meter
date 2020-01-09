#!/bin/bash

PREFIX=$1

if [ -z "$PREFIX" ]; then
   echo "Usage: $0 prefix"
   exit 1
fi

SEPARATOR="***********************************************"
VMAF_FILE=${PREFIX}_vmaf.json
VIFP_FILE=${PREFIX}_vifp.csv
SSIM_FILE=${PREFIX}_ssim.csv
MSSSIM_FILE=${PREFIX}_msssim.csv
PSNR_FILE=${PREFIX}_psnr.csv
PSNRHVS_FILE=${PREFIX}_psnrhvs.csv
PSNRHVSM_FILE=${PREFIX}_psnrhvsm.csv
PESQ_FILE=${PREFIX}_pesq.txt
VISQOL_FILE=${PREFIX}_visqol.txt

echo_avg() {
   title=$1
   value=$2
   echo "$SEPARATOR"
   echo "$title"
   echo "$SEPARATOR"
   echo "$value"
   echo ""
}

csv_avg() {
   filename=$1
   i=0
   sum=0
   while read -r line; do
      if [ ! $i = 0 ]; then
         array=(${line//,/ })
         sum=$(bc -l <<< "$sum+${array[1]}")
      fi
      i=$(($i+1))
   done < "$filename"
   i=$(($i-1))

   if [ ! $i = 720 ]; then
      echo "Error processing $filename ($i samples)"
      exit 1
   fi
   retval=$(bc -l <<< "$sum/$i")
}

if [ -f $VMAF_FILE ]; then
    value=$(tail -n 4 $VMAF_FILE | head -n 1)
    echo_avg "VMAF" "$value"
else
    echo $VMAF_FILE does not exists
fi

if [ -f $VIFP_FILE ]; then
    csv_avg $VIFP_FILE
    echo_avg "VIFp" "$retval"
else
    echo $VIFP_FILE does not exists
fi

if [ -f $SSIM_FILE ]; then
    csv_avg $SSIM_FILE
    echo_avg "SSIM" "$retval"
else
    echo $SSIM_FILE does not exists
fi

if [ -f $MSSSIM_FILE ]; then
    csv_avg $MSSSIM_FILE
    echo_avg "MS-SSIM" "$retval"
else
    echo $MSSSIM_FILE does not exists
fi

if [ -f $PSNR_FILE ]; then
    csv_avg $PSNR_FILE
    echo_avg "PSNR" "$retval"
else
    echo $PSNR_FILE does not exists
fi

if [ -f $PSNRHVS_FILE ]; then
    csv_avg $PSNRHVS_FILE
    echo_avg "PSNR-HVS" "$retval"
else
    echo $PSNRHVS_FILE does not exists
fi

if [ -f $PSNRHVSM_FILE ]; then
    csv_avg $PSNRHVSM_FILE
    echo_avg "PSNR-HVS-M" "$retval"
else
    echo $PSNRHVSM_FILE does not exists
fi

if [ -f $PESQ_FILE ]; then
    value=$(cat $PESQ_FILE)
    echo_avg "PESQ" "$value"
else
    echo $PESQ_FILE does not exists
fi

if [ -f $VISQOL_FILE ]; then
    value=$(cat $VISQOL_FILE)
    echo_avg "VISQOL" "$value"
else
    echo $VISQOL_FILE does not exists
fi
