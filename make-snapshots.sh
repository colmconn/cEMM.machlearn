#!/bin/bash

## set -x 

programName=`basename $0`

trap exit SIGHUP SIGINT SIGTERM

studyName=cEMM.machlearn

GETOPT=$( which getopt )
ROOT=/data/sanDiego/$studyName
DATA=$ROOT/data
LOG_DIR=$ROOT/log
SCRIPTS_DIR=${ROOT}/scripts

. ${SCRIPTS_DIR}/logger_functions.sh

if [[ "$#" -gt 0 ]] ; then
    subjects="$@"
else
    ## subjects=$( cd $DATA ; find ./ -maxdepth 1 \( -name '[0-9][0-9][0-9]_[ACD]' -o -name '[0-9][0-9][0-9]_[ACD]?' \) -printf "%f " )
    subjects=$( cd $DATA ; find ./ -maxdepth 1 \( -name '[0-9][0-9][0-9]_[A]' -o -name '[0-9][0-9][0-9]_[A]?' \) -printf "%f " )
fi

scriptExt=NL
enqueue=1

for subject in $subjects ; do

    outputScriptName=run/run-make-snapshots-${subject}.sh
    
    cat <<EOF > $outputScriptName
#!/bin/bash

set -x
#$ -S /bin/bash

cd $DATA/$subject

outputDir=afniEmmPreprocessed.$scriptExt
cd \${outputDir}
xmat_regress=X.xmat.1D 
pwd
if [[ -f \$xmat_regress ]] ; then 
   # make an image to check alignment
   $SCRIPTS_DIR/snapshot_volreg.sh  ${subject}_al_keep+orig            vr_base+orig.HEAD                ${subject}.orig.alignment
   $SCRIPTS_DIR/snapshot_volreg.sh  anat_final.${subject}+tlrc         pb02.${subject}.r01.volreg+tlrc  ${subject}.tlrc.alignment
fi
EOF

    chmod +x $outputScriptName
    if [[ $enqueue -eq 1 ]] ; then
	info_message_ln "Submitting job for execution to queuing system"
	LOG_FILE=$DATA/$subject/$subject-emm-make-snapshots.log
	info_message_ln "To see progress run: tail -f $LOG_FILE"
	rm -f ${LOG_FILE}
	qsub -N emm-$subject -q all.q -j y -m n -V -wd $( pwd )  -o ${LOG_FILE} $outputScriptName
    else
	info_message_ln "Job *NOT* submitted for execution to queuing system"
	info_message_ln "Pass -q or --enqueue options to this script to do so"	
    fi
    
done

if [[ $enqueue -eq 1 ]] ; then 
    qstat
fi
