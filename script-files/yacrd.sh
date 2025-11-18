#!/usr/bin/bash

#SBATCH --cpus-per-task=2
#SBATCH --mem=100G
#SBATCH -e "%x.e.%j.txt"
#SBATCH -o "%x.o.%j.txt"
#SBATCH --qos=short

TMPDIR=${SCRATCHDIR}

hostname

set -u

###################################################################################################
#extract variables
VARI=$(echo "$1" | sed 's/,/\t/g;s/"//g')
eval "$VARI"

TIME=$(date "+%s")

#source container based tools
source ${SCRIPT_DIR}tools

###################################################################################################

${SINGULARITYdir}minimap2.simg minimap2 -x ava-ont -t $SLURM_CPUS_PER_TASK -g 500 ${TMPdir}filtered_reads.fq.gz ${TMPdir}filtered_reads.fq.gz >${TMPdir}overlap.paf

export RUST_BACKTRACE=1
yacrd -i ${TMPdir}overlap.paf -o ${TMPdir}report.yacrd -c 2 -n 0.4 scrubb -i ${TMPdir}filtered_reads.fq.gz -o ${TMPdir}reads.scrubb.fasta
