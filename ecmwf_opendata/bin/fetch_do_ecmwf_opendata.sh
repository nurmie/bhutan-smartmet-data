#!/bin/bash/
# Script to download EMWCF opendata products from AWS
# Needs AWS CLI to be installed
# E.Nurmi 202404
# https://www.ecmwf.int/en/forecasts/datasets/open-data
# Ready times(UTC) for ECMWF IFS oper/scda model; 00z 07:55, 06z 13:15, 12z 19:55, 18z 01:15. These are indicative times check valid times during install and set cronjob accordingly.

set -ex

#Check the input
if [ $# -ne 1 ];
then
  echo " RUN [00,06,12,18] ?"
  exit 0
fi

# Set variables
MODEL_PRODUCER=ifs
MODEL_VERSION=0p25
MODEL_TYPE=oper
DATE=$(date -u +%Y%m%d)
ANALYSISTIME=$1
INCOMING_TMP=/smartmet/data/incoming/ecmwf_opendata/$DATE/$ANALYSISTIME
AREA='55,-19,146,47'
DOMAIN=
OUT=/smartmet/data/ecmwf_opendata
CNF=/smartmet/run/data/ecmwf_opendata/cnf
EDITOR=/smartmet/editor/in
TMP=/smartmet/tmp/data/ecmwf_opendata
OUTNAME=${DATE}${ANALYSISTIME}00_ecmwf_opendata
LOGFILE=/smartmet/logs/data/ecmwf_opendata_${ANALYSISTIME}.log

# Log everything
exec &> $LOGFILE

date

mkdir -p $INCOMING_TMP
mkdir -p $TMP
cd $TMP

# Different MODEL_TYPE for 06/18z
if [ $ANALYSISTIME -eq 06 ] || [ $ANALYSISTIME -eq 18 ]
 then
  MODEL_TYPE=scda
 else
  MODEL_TYPE=oper
fi

# Modify ANALYSISTIME for 18z
if [ $ANALYSISTIME -eq 18 ]
 then
  DATE=$(date -u +%Y%m%d -d "yesterday")
  OUTNAME=${DATE}${ANALYSISTIME}00_ecmwf_opendata
 else
  DATE=$(date -u +%Y%m%d)
fi

# Use sync command to download data from s3 bucket
time aws s3 sync --exclude "*" --include "*grib2" --no-sign-request s3://ecmwf-forecasts/${DATE}/${ANALYSISTIME}z/${MODEL_PRODUCER}/${MODEL_VERSION}/${MODEL_TYPE}/ ${INCOMING_TMP}/

# gribtoqd

# Surface
gribtoqd -t -n -d -c $CNF/ecmwf-surface.cnf -L 1 -p "240,ECMWF Surface" -G $AREA -o $TMP/${OUTNAME}_surface.sqd ${INCOMING_TMP}/20*h-*-fc.grib2

# Postproces, add Prec1h
qdscript -a 353 $CNF/ecmwf-surface.st < $TMP/${OUTNAME}_surface.sqd_levelType_1 > $TMP/${OUTNAME}_surface.sqd_levelType_1_tmp

# Versionfilter
qdversionchange -a -w 0 7 < $TMP/${OUTNAME}_surface.sqd_levelType_1_tmp > $TMP/${OUTNAME}_surface.sqd

# Pressure levels
gribtoqd -t -n -d -L 100 -p "240,ECMWF Pressure" -G $AREA -o $TMP/${OUTNAME}_pressure.sqd ${INCOMING_TMP}/20*h-*-fc.grib2
qdversionchange -a -w 0 7 < $TMP/${OUTNAME}_pressure.sqd_levelType_100 > $TMP/${OUTNAME}_pressure.sqd

# Deliver files to the product and editor directories
if [ -s $TMP/${OUTNAME}_surface.sqd ]; then
    echo -n "Compressing with pbzip2..."
    pbzip2 -p8 -k $TMP/${OUTNAME}_surface.sqd
    echo "done"

    echo -n "Copying file to SmartMet Production..."
    mv -f $TMP/${OUTNAME}_surface.sqd $OUT/surface/querydata/${OUTNAME}_surface.sqd
    mv -f $TMP/${OUTNAME}_surface.sqd.bz2 $EDITOR/
    echo "done"
    echo "Created files: ${OUTNAME}_surface.sqd"
fi
    
if [ -s $TMP/${OUTNAME}_pressure.sqd ]; then
    echo -n "Compressing with pbzip2..."
    pbzip2 -p8 -k $TMP/${OUTNAME}_pressure.sqd
    echo "done"

    echo -n "Copying file to SmartMet Production..."
    mv -f $TMP/${OUTNAME}_pressure.sqd $OUT/pressure/querydata/${OUTNAME}_pressure.sqd
    mv -f $TMP/${OUTNAME}_pressure.sqd.bz2 $EDITOR/
    echo "done"
    echo "Created files: ${OUTNAME}_pressure.sqd"
fi

# rsync files to the Centos7 2017 Smartmet server
rsync -av $OUT/surface/querydata/${OUTNAME}_surface.sqd 172.31.17.25:$OUT/surface/querydata/${OUTNAME}_surface.sqd
rsync -av $EDITOR/${OUTNAME}_surface.sqd.bz2 172.31.17.25:$EDITOR/${OUTNAME}_surface.sqd.bz2
rsync -av $OUT/pressure/querydata/${OUTNAME}_pressure.sqd 172.31.17.25:$OUT/pressure/querydata/${OUTNAME}_pressure.sqd
rsync -av $EDITOR/${OUTNAME}_pressure.sqd.bz2 172.31.17.25:$EDITOR/${OUTNAME}_pressure.sqd.bz2

# Clean up the mess
rm -rf $TMP/*sqd*
find ${INCOMING_TMP}/* -type f -name '20*h-*-fc.grib2' -mtime +1 -delete -print
find ${INCOMING_TMP}/* -type d -mtime +2 -delete -print

date
