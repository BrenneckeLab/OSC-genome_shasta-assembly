#!/usr/bin/bash

#SBATCH --cpus-per-task=2
#SBATCH --mem=50G
#SBATCH -e "%x.e.%j.txt"
#SBATCH -o "%x.o.%j.txt"   
#SBATCH --qos=short


TMPDIR=${SCRATCHDIR}

hostname

set -u


###################################################################################################
#extract variables 
VARI=$(echo "$1" | sed 's/,/\t/g;s/"//g' )
eval "$VARI"

TIME=$(date "+%s")

#source container based tools
source ${SCRIPT_DIR}tools

###################################################################################################

#filtering
#@ filtlong --min_length ${LENGTHcutoff} --min_mean_q ${QUALcutoff} -1 $ILLUMINAreadsFIRST -2 $ILLUMINAreadsMATE --trim --split 500 --target_bases ${reqBASES} ${TMPdir}reads.scrubb.fastq | gzip > ${TMPdir}filtered_reads.fq.gz
filtlong --min_length ${LENGTHcutoff} --target_bases ${reqBASES} ${TMPdir}reads.scrubb.fastq | gzip > ${TMPdir}filtered_reads.fq.gz

echo "filtered reads located @ ${TMPdir}filtered_reads.fq.gz"

PROCESSED_TIME=$(echo -e $(date "+%s") "$TIME" | mawk '{ print ($1-$2)/60 }' )
echo "read-filtering with FiltLong - processing time ="	"${PROCESSED_TIME}" >> "${rawOPENdir}time-log.txt"
TIME=$(date "+%s")


