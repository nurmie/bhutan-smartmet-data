#!/bin/sh
#
# Adedd pbzip2, rememer to install it.
#
# SmartMet Data Ingestion Module for GSM Model

#. /smartmet/cnf/data/wrf.cnf

AREA=bhutan
#DOMAIN=d02
OUT=/smartmet/data/gsm
CNF=/smartmet/run/data/gsm/cnf
EDITOR=/smartmet/editor/in
PRODUCER=99

#Check the input
if [ $# -ne 1 ];
then
  echo " RUN [00,12] ?"
  exit 0
fi

RUN=$1
#DOMAIN=$2

#UTCHOUR=$(date -u +%H -d '-3 hours')
UTCHOUR=$(date -u +%H)
DATE=$(date -u +%Y%m%d${RUN}00 -d '-9 hours')
#DATE=$(date -u +%Y%m%d${RUN}00)
#FILEDATE=$(date -u +%y%m%d${RUN}00 -d '-3 hours')
#FILEDATE=$(date -u +%y%m%d${RUN}00)
#FILEDATE=$(date -u +%y%m%d${RUN2}00)
TMP=/smartmet/tmp/data/gsm/$DATE/
LOGFILE=/smartmet/logs/data/gsm_${RUN}.log
OUTNAME=${DATE}_gsm_${AREA}
GSMDIR=/mnt/jica-nas/gtswis_data/nwp/gsm025
GSMDATE=$(date +%Y/%m/%d)
GSMDATA=${GSMDIR}/${GSMDATE}

# Log everything
exec &> $LOGFILE

echo $(date)

#mkdir -p $OUT/surface/querydata

# Check that we don't already have this analysis time
if [ -e $OUT/surface/querydata/${OUTNAME}_surface.sqd ]; then
    echo Model for time $DATE exists already!
    exit 0
fi

mkdir -p $TMP/grib

cd $TMP/grib

echo "Moving files from incoming...."
cp -p ${GSMDATA}/*_grib2* .
if [ $? -ne 0 ]
then
    echo "error with mv to tmp"
fi
echo "done"
#

echo "Analysis time: $DATE"
echo "Model Run: $RUN"

echo "Converting grib files to qd files..."
# Surface parameters
gribtoqd -d -c $CNF/gsm.cnf -n -t -L 1 -p "${PRODUCER},GSM Surface" -o $TMP/${OUTNAME}.sqd $TMP/grib/

echo "done"

# Postprocessing
#mv -f $TMP/$OUTNAME.sqd_levelType_1 $TMP/${OUTNAME}_surface.sqd.tmp
#mv -f $TMP/$OUTNAME.sqd_levelType_100 $TMP/${OUTNAME}_pressure.sqd.tmp
qdscript $CNF/gsm-surface.st < $TMP/${OUTNAME}.sqd_levelType_1 > $TMP/${OUTNAME}_surface.sqd.tmp

#
# Create querydata totalWind and WeatherAndCloudiness objects
#
echo -n "Creating Wind objects:..."
qdversionchange -a 7 < $TMP/${OUTNAME}_surface.sqd.tmp > $TMP/${OUTNAME}_surface.sqd
echo "done"

#
# Copy files to SmartMet Workstation and SmartMet Production directories
#

if [ -s $TMP/${OUTNAME}_surface.sqd ]; then
    echo -n "Compressing with pbzip2..."
    pbzip2 -p8 -k $TMP/${OUTNAME}_surface.sqd
    echo "done"

    echo -n "Copying file to SmartMet Production..."
    mv -f $TMP/${OUTNAME}_surface.sqd $OUT/surface/querydata/${OUTNAME}_surface.sqd
    mv -f $TMP/${OUTNAME}_surface.sqd.bz2 $EDITOR/
    echo "done"
    echo "Created files: ${OUTNAME}_surface.sqd"
    #echo -n "Copying file to SmartMet Production..."
    #mv -f $TMP/${OUTNAME}_pressure.sqd $OUT/pressure/querydata/${OUTNAME}_pressure.sqd
    #cp -f $OUT/pressure/querydata/${OUTNAME}_pressure.sqd $EDITOR/${OUTNAME}_pressure.sqd
    #mv -f $TMP/${OUTNAME}_pressure.sqd.bz2 $EDITOR/
    #echo "done"
    #echo "Created files: ${OUTNAME}_pressure.sqd"
fi

# Clean up the mess
rm -rf $TMP

echo $(date)
