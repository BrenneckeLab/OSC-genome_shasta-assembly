#!/bin/bash
###############################################################################################
set -u

# Argument = -i input -c chunksize -D blast-database -v
usage() {
  cat <<EOF
  usage: $0 options
  
  ###############################################################################
  This tool calculates read counts on a template of choice. It reportes the 
  counts for both, the sense and the antisense strand.
  
  usage: [PATH]/selectUTRs [options] -F 
  
  OPTIONS:
      -h  Show this message
      -V  assembly version
            e.g. V01
      -N  name extension
            default is basic-assembly
      -G  Name of Genotype the DNA originates from 
      -R  path to raw-fasta file
            only required if external fasta with all reads is available
      -A  process all nanopore runs available for current genotype
      -C  set flag for local processing (use only if multiple cores available)
      -D  sed debug mode - does not trigger git commit
      -F  force regeneration of filtered reads
      -f  force restart of assembly by deleting assembly-folder
      -w  delete all directories to start completely fresh
EOF
}

assemblyNAME=basic-assembly
assemblyVERSION=
GENOTYPE=
rawFASTA=
ALL=
COMPUTING=C
DEBUG=N
SYSTEM=CBE
FORCE=N
FORCErestartASSEMBLY=N
FORCEregenerationREADS=N
WIPE=N

while getopts ÒhN:V:G:R:ACDFfw,Ó OPTION; do
  case $OPTION in
  h)
    usage
    exit 1
    ;;
  N)
    assemblyNAME=$OPTARG
    ;;
  V)
    assemblyVERSION=$OPTARG
    ;;
  G)
    GENOTYPE=$OPTARG
    ;;
  R)
    rawFASTA=$OPTARG
    ;;
  A)
    ALL=Y
    ;;
  C)
    COMPUTING=L
    ;;
  D)
    DEBUG=Y
    ;;
  F)
    FORCEregenerationREADS=Y
    ;;
  f)
    FORCErestartASSEMBLY=Y
    ;;
  w)
    WIPE=Y
    ;;

  ?)
    usage
    exit
    ;;
  esac
done

###################################################################################################
#settings
#@!@#

#Albacore version used
BCversion="GUPPY_SUPER_5.0.7+2332e8d65_dna_r9.4.1_450bps_sup"

#genome size for coverage calculation in Mb
GENOMEsize=144
#minimal coverage during read-selection
minCOVERAGE=100
#minimal length for reads to consider
LENGTHcutoff=15000
#minimal mean quailty of read
QUALcutoff=65
#path to Illumina reads of genome to assembly for read-filtering
ILLUMINAreadsFIRST=
ILLUMINAreadsMATE=
ILLUMINAmixed=

#download link for reference genome sequence
REFgenome=http://ftp.flybase.net/genomes/Drosophila_melanogaster/current/fasta/dmel-all-chromosome-r6.39.fasta.gz

#path to already filtered and prepared read-file
##leave empty if read correction should be performed during the run
preparedREADS=""
#path to storage of raw-data
RAW=
#path to open-directory
OPEN=
#path to tmp-storage
TMP=

#@!@#
###################################################################################################
#test if all required variables supplied

if [[ -z $assemblyVERSION ]]; then
  #usage
  printf "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!\n"
  printf "       Please provide assembly version in option V!\n"
  printf "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!\n\n"
  exit
fi
if [[ -z $GENOTYPE ]]; then
  #usage
  printf "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!\n"
  printf "       Please provide Genotype in option G!\n"
  printf "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!\n\n"
  exit
fi

#@ if [[ ! -z $rawFASTA && ! -s $rawFASTA ]]; then
#@   #if no raw-fasta file is provided test if the provided genotype is correct
#@   #usage
#@   printf "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!\n"
#@   printf "       no file found in path for raw fasta file !\n"
#@   printf "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!\n\n"
#@   exit
#@ fi
echo a
###################################################################################################
#variable-setup
DATE_OF_DAY=$(date +%F)
FULL_DATE=$(date)
#DATE_OF_DAY=2017-02-14

OPENdir=${OPEN}${GENOTYPE}/${BCversion}_${assemblyVERSION}/
TMPdir=${TMP}${GENOTYPE}/${BCversion}_${assemblyVERSION}/

#location of all singularity images
SINGULARITYdir=${TMPdir}singularity/

#remove all output directories if requested
if [[ $WIPE == Y ]]; then
  rm -rf $OPENdir
  rm -rf $TMPdir
fi

#generate output directories
mkdir -p $OPENdir
mkdir -p $TMPdir

###################################################################################################
#preset scripts

#determine script-location
SOURCE="${BASH_SOURCE[0]}"
while [ -h "$SOURCE" ]; do # resolve $SOURCE until the file is no longer a symlink
  DIR="$(cd -P "$(dirname "$SOURCE")" && pwd)"
  SOURCE="$(readlink "$SOURCE")"
  [[ $SOURCE != /* ]] && SOURCE="$DIR/$SOURCE" # if $SOURCE was a relative symlink, we need to resolve it relative to the path where the symlink file was located
done

#generate final SCRIPT_DIR variables
SCRIPT_DIRraw="$(cd -P "$(dirname "$SOURCE")" && pwd)"
SCRIPT_DIRraw="${SCRIPT_DIRraw}/"
SCRIPT_DIR="${SCRIPT_DIRraw}script-files/"
UTILITY_DIR="${SCRIPT_DIRraw}utility-files/"

echo a
###################################################################################################
#download required singularity modules
mkdir -p ${SINGULARITYdir}
cd ${SINGULARITYdir}

wget -O MARVEL.app https://brenneckelab.imba.oeaw.ac.at/Publication_Data/2025_Handler_OSC-genome/Apptainer/MARVEL.app
wget -O minimap2.app https://brenneckelab.imba.oeaw.ac.at/Publication_Data/2025_Handler_OSC-genome/Apptainer/minimap2.app
wget -O yacrd.app https://brenneckelab.imba.oeaw.ac.at/Publication_Data/2025_Handler_OSC-genome/Apptainer/yacrd.app
wget -O basicTools.app https://brenneckelab.imba.oeaw.ac.at/Publication_Data/2025_Handler_OSC-genome/Apptainer/basicTools.app

###################################################################################################
#push git version and commit

cd ${SCRIPT_DIRraw}
echo ${SCRIPT_DIRraw}
if [[ $DEBUG != Y ]]; then

  #ask for commit-message
  while true; do
    read -r -p "Plese specify a commit-message: " msg
    case $msg in
    [Nn]) break ;;
    *)
      commitMESSAGE=$msg
      break
      ;;
    esac
  done

  #commit all changes
  git add .
  if [[ -z $commitMESSAGE ]]; then
    git commit -m "automatic commit on submission"
  else
    git commit -m "$commitMESSAGE"
  fi
  git push --all
fi

commitID=$(git log -1 --pretty=format:"%h")
commitTEXT=$(git log -1 --pretty=format:"%f")

###################################################################################################
###################################################################################################
#determine nanopore runs to use for assembly
if [[ -z $rawFASTA ]]; then
  #determine available RUNs for current genotype and molecule type
  ls -l ${RAW} | grep ${GENOTYPE} | grep DNA | awk -v OFS="\t" '{print NR, $NF}' >${TMPdir}available_runs.txt
  cat ${TMPdir}available_runs.txt

  if [[ ! -s ${TMPdir}available_runs.txt ]]; then
    printf "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!\n"
    printf "       no nanopore runs available - check genotype!\n"
    printf "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!\n\n"
    exit
  fi

  #ask user for input

  rm -rf ${TMPdir}selected-runs.txt
  while true; do
    if [[ -z $ALL ]]; then
      read -p "Which Nanopore Run's to analyze? [# in list above or comma separate list or A for all]" NR
    else
      NR=$ALL
    fi
    case $NR in
    [1-9] | [1-9][0-9])
      cat ${TMPdir}available_runs.txt | awk -v locTMP=${TMPdir} -v xNR=$NR ' BEGIN {xswitch=0}; 
             { if($1==xNR) { xswitch=1; print "RUN \""$0"\" selected"; print $NF > locTMP "selected-run.txt" } }
                  END { print xswitch > locTMP"switch.txt"}' | tr '\t' ' '
      switch=$(cat ${TMPdir}switch.txt)
      if [[ $switch == 1 ]]; then
        RUNs=$(cat ${TMPdir}selected-run.txt)
        break
      else
        cat ${TMPdir}available_runs.txt
        printf "\nplease select existing run \n\n"
      fi
      ;;
    [Aa])
      RUNs=$(cat ${TMPdir}available_runs.txt | cut -f 2 | tr '\n' '\t')
      break
      ;;
    *)
      echo $NR | awk -v INFILE=${TMPdir}available_runs.txt -v OUTFILE=${TMPdir}selected-runs.txt '
                      BEGIN{
                        while((getline RAW_LINES < INFILE) > 0) {split(RAW_LINES,splitLINES,/\t| /); availSELECTION[splitLINES[1]]=splitLINES[2] }
                        EXIT="Y"
                      } 
                      { 
                        N=split($1, X, /,/)
                        if( N==1) {
                          print  "\n\n\nplease supply runs in a valid comma separated format"
                        }else{
                          for( i in X){
                            if( X[i] in availSELECTION ) {
                              if(OUTSTRING==""){
                                OUTSTRING=availSELECTION[X[i]]
                              }else{
                                OUTSTRING=OUTSTRING" "availSELECTION[X[i]]
                              }
                            }else{
                              print "selected run #"X[i]" not available for selection" 
                              EXIT=N
                            }
                          }
                          if(EXIT == "Y" ){
                            print OUTSTRING > OUTFILE 
                          }
                        }
                      }'
      if [[ -f ${TMPdir}selected-runs.txt ]]; then
        RUNs=$(cat ${TMPdir}selected-runs.txt)
        break
      fi
      ;;

    esac

  done
  subRUNs=$(echo $RUNs | tr ' ' '\t' | tr '\t' '~')  
else
  subRUNs=""
fi

###################################################################################################
#setup logging

LOG=${OPENdir}/LOGs/
mkdir -p ${LOG}
rm -rf ${LOG}asm_${assemblyVERSION}_${assemblyNAME}*.txt
cd $LOG

mkdir -p ${LOG}/settings/

cat ${SCRIPT_DIRraw}*.sh |
  awk -v RS="#@!@#" '{if (NR==2) print }' >${LOG}/settings/SETTINGS_${commitID}.log

{ 
  echo Options used: "$@" 
  echo Nanopore Runs used: 
  echo $subRUNs | tr '~' '\n' 
}>>${LOG}/settings/SETTINGS_${commitID}.log


###################################################################################################
#move scripts to TMP-directory
mkdir -p ${LOG}/scripts/$commitID/
cp -r ${SCRIPT_DIR}* ${LOG}/scripts/$commitID/
SCRIPT_DIR=${LOG}//scripts/${commitID}/

mv ${SCRIPT_DIR}main.sh ${SCRIPT_DIR}asm_${assemblyVERSION}_${assemblyNAME}.sh

###################################################################################################
#submit main-run script

COMMAND=${SCRIPT_DIR}asm_${assemblyVERSION}_${assemblyNAME}.sh
VARI="assemblyVERSION=${assemblyVERSION},GENOTYPE=${GENOTYPE},GENOMEsize=${GENOMEsize},minCOVERAGE=${minCOVERAGE},LENGTHcutoff=${LENGTHcutoff},QUALcutoff=${QUALcutoff},SINGULARITYdir=${SINGULARITYdir},COMPUTING=${COMPUTING},SCRIPT_DIR=${SCRIPT_DIR},UTILITY_DIR=${UTILITY_DIR},BCversion=${BCversion},RAW=${RAW},TMPdir=${TMPdir},OPENdir=${OPENdir},LOG=${LOG},commitID=${commitID},commitTEXT=${commitTEXT},DATE_OF_DAY=${DATE_OF_DAY},LOG=${LOG},assemblyNAME=${assemblyNAME},ILLUMINAreadsFIRST=${ILLUMINAreadsFIRST},ILLUMINAreadsMATE=${ILLUMINAreadsMATE},ILLUMINAmixed=${ILLUMINAmixed},preparedREADS=${preparedREADS},FORCEregenerationREADS=${FORCEregenerationREADS},FORCErestartASSEMBLY=${FORCErestartASSEMBLY},subRUNs=${subRUNs},REFgenome=${REFgenome},rawFASTA=${rawFASTA}"


if [[ $COMPUTING == C ]]; then
  sbatch $COMMAND ${VARI}
else
  if [[ -z ${SLURM_CPUS_PER_TASK+x} ]]; then
    srun --cpus-per-task=10 --mem=20g --time=1:00:00 --qos=short $COMMAND ${VARI}
  else
    $COMMAND ${VARI}
  fi
fi
exit
