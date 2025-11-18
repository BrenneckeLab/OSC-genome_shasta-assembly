#!/bin/bash

#SBATCH --cpus-per-task=1
#SBATCH --mem=20g
#SBATCH -e "%x.e.%j.txt"
#SBATCH -o "%x.o.%j.txt"
#SBATCH --qos=medium
##$SBATCH --time=:00:00

hostname
set -u

###################################################################################################
#extract variables
VARI=$(echo "$1" | sed 's/,/\t/g;s/"//g')
eval "$VARI"
origVARI=$1

#report all variables to log
echo $1 | tr ',' '\n'

#initiate time-variable
TIME=$(date "+%s")
TIMEx=$(date "+%s")

echo "started analysis" >${LOG}time-log.txt
###################################################################################################
#setup-phase

#load tools
source ${SCRIPT_DIR}tools

#add original opendir to original vari
rawOPENdir=$OPENdir
origVARI=${origVARI},rawOPENdir=${rawOPENdir}

###################################################################################################

#create opendir for read-preparation
OPENdir=${rawOPENdir}/read-preparation/
mkdir -p $OPENdir

#prepare reads if not supplied as corrected reads or already generated previously
if [[ -z $preparedREADS ]]; then
  if [[ ! -f ${OPENdir}filtered_reads.fq.gz || $FORCEregenerationREADS == Y ]]; then
    printf "preparation of reads:" >>"${LOG}time-log.txt"
    #preparation of input reads
    VARI=${origVARI},OPENdir=${OPENdir}
    mkdir -p ${LOG}read-preparation/
    cd ${LOG}read-preparation/
    rm -rf ${LOG}read-preparation//*
    
    #download reference for mapping steps
    if [[ ! -s ${TMPdir}REF.fa.gz ]]; then  
      curl $REFgenome > ${TMPdir}REF.fa.gz
    fi

    #split libraries into individual names
    splitONT_RUNs=$(echo $subRUNs | tr '~' '\t')
    
    if [[ ! -z $rawFASTA ]]; then
      cp $rawFASTA ${TMPdir}reads.fq
    else
      #remove existing fastq-file and regenerate
      rm -rf ${TMPdir}reads.fq.gz
      for RUN in $splitONT_RUNs; do
        seqkit seq --remove-gaps --line-width 0 --min-len $LENGTHcutoff ${RAW}/${RUN}/reads/${BCversion}/trimmed/* >>${TMPdir}reads.fq
      done
    fi
    
    #submint plotting of raw-read statistics
    COMMAND=${SCRIPT_DIR}NanoPlot.sh
    if [[ $COMPUTING == C ]]; then
      sbatch $COMMAND ${VARI},TYPE=raw,INPUT=${TMPdir}reads.fq
    else
      sleep 1s
    fi

    
    #report time to log
    PROCESSED_TIME=$(echo -e $(date "+%s") "$TIMEx" | mawk '{ print ($1-$2)/60 }')
    printf "  merging of fastq-files - total time = ${PROCESSED_TIME}\n" >>"${LOG}time-log.txt"
    TIMEx=$(date "+%s")
    
    #@ #---------------------------------------------------------------------------------------------------------
    #scrub reads with yacrd
    #?mv ${TMPdir}reads.fq ${TMPdir}reads.scrubb.fastq
    sbatch -o "%x.o.%A-%a.txt" -e "%x.e.%A-%a.txt" --wait --cpus-per-task=38 --time=8:00:00 --mem 160g --job-name=minimap-yacrd --wrap="SINGULARITYdir=${SINGULARITYdir}; source ${SCRIPT_DIR}tools; CORES=\$(( SLURM_CPUS_PER_TASK * 2 )); minimap2 -2 -x ava-ont -t \$CORES -g 500 ${TMPdir}reads.fq ${TMPdir}reads.fq >${TMPdir}overlap.paf"
    
    sbatch -o "%x.o.%A-%a.txt" -e "%x.e.%A-%a.txt" --wait --cpus-per-task=1 --time=8:00:00 --mem 50g --job-name=yacrd --wrap="SINGULARITYdir=${SINGULARITYdir}; source ${SCRIPT_DIR}tools; yacrd -i ${TMPdir}overlap.paf -o ${TMPdir}report.yacrd -c 4 -n 0.4 scrubb -i ${TMPdir}reads.fq -o ${TMPdir}reads.scrubb.fastq"
    
    awk -v OFS="\t" '{X[$1]+=1; TOTAL+=1}END{for(i in X){print i,X[i]*100/TOTAL}}' ${TMPdir}report.yacrd > ${OPENdir}scrubbing.result.txt
    
    #submit plotting of scrubbed-read statistics
    COMMAND=${SCRIPT_DIR}NanoPlot.sh
    
    if [[ $COMPUTING == C ]]; then
      sbatch $COMMAND ${VARI},TYPE=scrubbed,INPUT=${TMPdir}reads.scrubb.fastq
    else
      sleep 1s
    fi
    
    #---------------------------------------------------------------------------------------------------------
    #calculate amount of bases required for coverage
    reqBASES=$(echo $(($GENOMEsize * 1000000 * $minCOVERAGE)))
    echo $reqBASES
    printf "bases required for ${minCOVERAGE}x = $reqBASES\n\n" >>${OPENdir}log.txt
    
    sbatch -o "%x.o.%A-%a.txt" -e "%x.e.%A-%a.txt" --wait --cpus-per-task=2 --partition=m --time=8:00:00 --mem 100g --job-name=filtlong --wrap="SINGULARITYdir=${SINGULARITYdir}; source ${SCRIPT_DIR}tools; 
      filtlong  --target_bases ${reqBASES} ${TMPdir}reads.scrubb.fastq | gzip > ${TMPdir}filtered_reads.fq.gz"
    

    #---------------------------------------------------------------------------------------------------------
    #test if fq file is valid
    TEST=$(seqkit seq ${TMPdir}filtered_reads.fq.gz | head -n 1)

    if [[ -z $TEST ]]; then
      echo read filtering failed
      exit
    fi
    
    #transfer filtered reads to permanent storage in OPENdir and re-set read-variable
    mv ${TMPdir}filtered_reads.fq.gz ${OPENdir}filtered_reads.fq.gz
    READS=${OPENdir}filtered_reads.fq.gz
    
    #---------------------------------------------------------------------------------------------------------
    #submit plotting of filtered-read statistics
    COMMAND=${SCRIPT_DIR}NanoPlot.sh
    
    if [[ $COMPUTING == C ]]; then
      sbatch $COMMAND ${VARI},TYPE=filtered,INPUT=${OPENdir}filtered_reads.fq.gz
    else
      sleep 1s
    fi
    
    #report time to log
    PROCESSED_TIME=$(echo -e $(date "+%s") "$TIMEx" | mawk '{ print ($1-$2)/60 }')
    echo "read-filtering with FiltLong - total time = ${PROCESSED_TIME}\n" >>"${LOG}time-log.txt"
    TIMEx=$(date "+%s")
    
    
    elif [[ ! -z $preparedREADS ]]; then
    #transfer reads supplied as preparedREADS into permanent sotrage and re-set read-variable
    mkdir -p $OPENdir
    cp $preparedREADS ${OPENdir}
    READS=${OPENdir}${preparedREADS##*/}
  fi
  
  #set read variable to existing filtered reads
  READS=${OPENdir}filtered_reads.fq.gz
fi

PROCESSED_TIME=$(echo -e $(date "+%s") "$TIME" | mawk '{ print ($1-$2)/60 }')
printf "\n\nread-processing - total time = ${PROCESSED_TIME}\n\n" >>${LOG}time-log.txt


TEST=$(seqkit fq2fa $READS | head -n 1)
if [[ -z $TEST ]]; then
  >&2 echo filtered reads not valid 
  exit
fi


###################################################################################################
#submission of assembly

TIME=$(date "+%s")
OPENdir=${rawOPENdir}assembly/${assemblyNAME}/

mkdir ${LOG}assembly/
cd ${LOG}assembly/

#wipe assembly directory if requested
if [[ $FORCErestartASSEMBLY == Y ]]; then
  rm -rf ${OPENdir}
fi
mkdir -p $OPENdir

#report start of assembly including commit-ID to time-log
printf "\nassembly with commit $commitID - $commitTEXT:\n" >>${LOG}time-log.txt

#submit assembly
if [[ $COMPUTING == C ]]; then
  sbatch --wait --cpus-per-task=20 --mem=60g  --wrap="shasta --input ${READS} --config ${SCRIPT_DIR}shasta-config.txt"
else
  shasta --input ${READS} --config ${SCRIPT_DIR}shasta-config.txt
fi

PROCESSED_TIME=$(echo -e $(date "+%s") "$TIME" | mawk '{ print ($1-$2)/60 }')
printf "Shasta assembly - total time = ${PROCESSED_TIME}\n\n" >>${LOG}time-log.txt

echo ${OPENdir}/${assemblyVERSION}.fasta

exit
