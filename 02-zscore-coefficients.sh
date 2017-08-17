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
    subjects=$( cd $DATA  ; ls -d [0-9][0-9][0-9]_{A,C,D} [0-9][0-9][0-9]_{A,C,D}2 2> /dev/null | grep -v 999 )
fi

regressorLabels="Neutral_all Happy Sad Fear"

for subject in ${subjects} ; do

    if [[ -f $DATA/$subject/afniEmmPreprocessed.NL/stats.${subject}+tlrc.HEAD ]] ; then 
	cd $DATA/$subject/afniEmmPreprocessed.NL/

	maskFile=full_mask.${subject}+tlrc.HEAD

	for regressorLabel in ${regressorLabels} ; do

	    ## get the subbrik indices of the first and last sub-brik for the coefficients of the regressor of interest
	    firstSubBrik=$( 3dinfo -label2index $( 3dinfo -label stats.${subject}+tlrc.HEAD | tr '|' "\n" | grep ${regressorLabel} | grep Coef | head -1 ) stats.${subject}+tlrc. )
	    lastSubBrik=$(  3dinfo -label2index $( 3dinfo -label stats.${subject}+tlrc.HEAD | tr '|' "\n" | grep ${regressorLabel} | grep Coef | tail -1 ) stats.${subject}+tlrc. )

	    info_message_ln "Coefficients for the ${regressorLabel} regressor start at: ${firstSubBrik} and end at ${lastSubBrik}"
	    
	    info_message_ln "Extracting coefficients for the ${regressorLabel} regressor for subject ${subject}"

	    ## the (2) selects every second subbrik since for every
	    ## coefficient brik there is a corresponding stats brik
	    ## which we are not intrested in
	    3dbucket -prefix rm_coef.${regressorLabel} stats.${subject}+tlrc.HEAD\[${firstSubBrik}..${lastSubBrik}\(2\)\]

	    ## compute the mean and standard deviation for each voxel
	    info_message_ln "Computing mean and standard deviation"
	    3dTstat -mean -stdev -mask ${maskFile} -prefix rm_coef.mean.stdev.${regressorLabel} rm_coef.${regressorLabel}+tlrc.

	    ## note that for variable c (which corresponds to the
	    ## standard deviation) we have to use the numberic
	    ## sub-brik selector since there seems to be no way to
	    ## provide a sub-brik label to 3dcalc that contains a
	    ## space. Why is this a problem? The 3dTstat command above
	    ## creates a sub-brik for the standard deviation with
	    ## label"Std Dev" which 3dcalc does not like. Go figure.
	    ##
	    ## now compute the z-score
	    info_message_ln "Computing z-scores"
	    3dcalc -a rm_coef.${regressorLabel}+tlrc.HEAD			\
		   -b rm_coef.mean.stdev.${regressorLabel}+tlrc.HEAD'[Mean]'	\
		   -c rm_coef.mean.stdev.${regressorLabel}+tlrc.HEAD'[1]'	\
		   -d ${maskFile}						\
		   -expr '((a-b)/c)*step(d)'					\
		   -prefix coef.zscore.${regressorLabel}.${subject}
	done

	info_message_ln "Combining z-scores into one bucket file: coef.zscore.${subject}+tlrc"
	3dbucket -prefix coef.zscore.${subject} $( eval echo "coef.zscore.{$( echo ${regressorLabels} | tr -s " " "," )}.${subject}+tlrc.HEAD" )

	## delete all the unneeded intermediate files
	rm rm_coef.*
    else
	warn_mesage_ln "No stats file found for ${subject}. Skipping"
    fi
done
