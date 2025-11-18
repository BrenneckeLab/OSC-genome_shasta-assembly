#!/usr/bin/bash

#SBATCH --cpus-per-task=5
#SBATCH --mem=30G
#SBATCH -e "%x.e.%j.txt"
#SBATCH -o "%x.o.%j.txt"   
#SBATCH --qos=short

hostname
set -u

###################################################################################################
#extract variables 
VARI=$(echo "$1" | sed 's/,/\t/g;s/"//g' )
eval "$VARI"

TIME=$(date "+%s")

#source container based tools
source ${SCRIPT_DIR}tools

#clean up directories
rm -rf ${OPENdir}NanoPlot-${TYPE}/*
rm -rf ${OPENdir}NanoPlot-${TYPE}_mapped/*

###################################################################################################
#map reads to reference genome
CORES=$(( SLURM_CPUS_PER_TASK * 2 ))
minimap2 -x map-ont --secondary=no -a -t $CORES  ${TMPdir}REF.fa.gz $INPUT | 
  samtools sort --output-fmt bam --threads $CORES -  > ${TMPdir}$TYPE.sort.bam

samtools index ${TMPdir}$TYPE.sort.bam 

#determine read type
HEAD=$(seqkit seq $INPUT | head -n 1)
if [[ $HEAD == ">"* ]]; then FILE=fasta; else FILE=fastq; fi

#run nanoplot
  NanoPlot -t $SLURM_CPUS_PER_TASK --loglength --N50 --title $TYPE --readtype 1D -o ${OPENdir}NanoPlot-${TYPE} --${FILE} $INPUT
  NanoPlot -t $SLURM_CPUS_PER_TASK --loglength --N50 --title ${TYPE}_mapped --readtype 1D -o ${OPENdir}NanoPlot-${TYPE}_mapped --bam ${TMPdir}$TYPE.sort.bam

  PROCESSED_TIME=$(echo -e $(date "+%s") "$TIME" | mawk '{ print ($1-$2)/60 }' )
  echo "plotting of read stats with NanoPlot for $TYPE reads - processing time ="	"${PROCESSED_TIME}" >> "${OPENdir}time-log.txt"
  TIME=$(date "+%s")
  
