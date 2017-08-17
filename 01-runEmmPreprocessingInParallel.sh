#!/bin/bash

# set -x 

programName=`basename $0`

trap exit SIGHUP SIGINT SIGTERM

studyName=cEMM.machlearn

GETOPT=$( which getopt )
ROOT=/data/sanDiego/$studyName
DATA=$ROOT/data
LOG_DIR=$ROOT/log
SCRIPTS_DIR=${ROOT}/scripts

. ${SCRIPTS_DIR}/logger_functions.sh

GETOPT_OPTIONS=$( $GETOPT \
		      -o "fe:m:o:h:b:t:nq" \
		      --longoptions "force,excessiveMotionThresholdFraction:,motionThreshold:,outlierThreshold:,threads:,blur:,tcat:,nonlinear,enqueue" \
		      -n ${programName} -- "$@" )
exitStatus=$?
if [ $exitStatus != 0 ] ; then 
    echo "Error with getopt. Terminating..." >&2 
    exit $exitStatus
fi

## 1 = force creation of zero padded files
force=0

## enqueue the job for execution
enqueue=0

# Note the quotes around `$GETOPT_OPTIONS': they are essential!
eval set -- "$GETOPT_OPTIONS"
while true ; do 
    case "$1" in
	-f|--force)
	    force=1; shift 1;;
	-e|--excessiveMotionThresholdFraction)
	    excessiveMotionThresholdFraction=$2; shift 2 ;;	
	-m|--motionThreshold)
	    motionThreshold=$2; shift 2 ;;	
	-o|--outlierThreshold)
	    outlierThreshold=$2; shift 2 ;;	
	-h|--threads)
	    threads=$2; shift 2 ;;	
	-b|--blur)
	    blur=$2; shift 2 ;;	
	-t|--tcat)
	    tcat=$2; shift 2 ;;	
	-n|--nonlinear)
	    nonlinear=1; shift 1 ;;	
	-q|--enqueue)
	    enqueue=1; shift 1 ;;	
	--) 
	    shift ; break ;;

	*) 
	    echo "${programName}: ${1}: invalid option" >&2
	    exit 2 ;;
    esac
done

# if [[ $force -eq 1 ]] ; then
#     info_message_ln "Forcing recreation of ZEROPADed files"
# fi

####################################################################################################
## Check that appropriate values are used to initialize arguments that
## control analysis if no values were provided on the command line

## The following values are used to exclude subjects based on the
## number of volumes censored during analysis
if [[ "x$excessiveMotionThresholdFraction" == "x" ]] ; then
    excessiveMotionThresholdFraction=0.2
    excessiveMotionThresholdPercentage=20
    warn_message_ln "No excessiveMotionThresholdFraction threshold was provided. Defaulting to $excessiveMotionThresholdFraction => ${excessiveMotionThresholdPercentage}%"
else
    excessiveMotionThresholdPercentage=$( echo "(($excessiveMotionThresholdFraction*100)+0.5)/1" | bc ) 

    info_message_ln "Using ${excessiveMotionThresholdFraction} as the subject exclusion motion cutoff fraction"
    info_message_ln "Using ${excessiveMotionThresholdPercentage}% as subject exclusion motion cutoff percentage"
    info_message_ln "Note that these values are used to exclude subjects based on the number of volumes censored during analysis"
fi


## motionThreshold and outlierThreshold are the values passed to
## afni_proc.py and are used when deciding to censor a volume or not
if [[ "x${motionThreshold}" == "x" ]] ; then
    motionThreshold=0.2
    warn_message_ln "No motionThreshold value was provided. Defaulting to $motionThreshold"
else
    info_message_ln "Using motionThreshold of ${motionThreshold}"
fi

if [[ "x${outlierThreshold}" == "x" ]] ; then
     outlierThreshold=0.1
     warn_message_ln "No outlierThreshold value was provided. Defaulting to $outlierThreshold"
else
    info_message_ln "Using outlierThreshold of ${outlierThreshold}"
fi

if [[ "x${threads}" == "x" ]] ; then
     threads=1
     warn_message_ln "No value for the number of parallel threads to use was provided. Defaulting to $threads"
else
    info_message_ln "Using threads value of ${threads}"
fi

# if [[ "x${blur}" == "x" ]] ; then
#      blur="8"
#      warn_message_ln "No value for blur filter value to use was provided. Defaulting to $blur"
# else
#     info_message_ln "Using blur filter value of ${blur}"
# fi

# if [[ "x${tcat}" == "x" ]] ; then
#      tcat="3"
#      warn_message_ln "No value for tcat, the number of TRs to censor from the start of each volume, was provided. Defaulting to $tcat"
# else
#     info_message_ln "Using tcat filter value of ${tcat}"
# fi

if [[ $nonlinear -eq 1 ]] ; then 
    info_message_ln "Using nonlinear alignment"
    scriptExt="NL"
else 
    info_message_ln "Using affine alignment only"
    scriptExt="aff"    
fi

####################################################################################################
if [[ "$#" -gt 0 ]] ; then
    subjects="$@"
else
    ## subjects=$( cd $DATA ; find ./ -maxdepth 1 \( -name '[0-9][0-9][0-9]_[ACD]' -o -name '[0-9][0-9][0-9]_[ACD]?' \) -printf "%f " )
    ## subjects=$( cd $DATA ; find ./ -maxdepth 1 \( -name '[0-9][0-9][0-9]_[A]' -o -name '[0-9][0-9][0-9]_[A]?' \) -printf "%f " )

    subjects=$( cd ../data/ ; ls -d [0-9][0-9][0-9]_{C,D} [0-9][0-9][0-9]_{C,D}2 2> /dev/null | grep -v 999 )
fi

## timepointLimiter=baselineOnly
timepointLimiter=followupOnly
alignmentParametersShellScriptFile=${SCRIPTS_DIR}/EMM_alignment_parameters.${timepointLimiter}.sh

[[ -d run ]] || mkdir run

for subject in $subjects ; do
    info_message_ln "#################################################################################################"
    info_message_ln "Generating script for subject $subject"

    if  [[ ! -f ${DATA}/$subject/${subject}EMM+orig.HEAD ]] ; then
	warn_message_ln "Can not find EMM EPI file for ${subject}. Skipping."
	continue
    else
	epiFile=${DATA}/$subject/${subject}EMM+orig.HEAD
    fi

    if  [[ ! -f ${DATA}/$subject/${subject}+orig.HEAD ]] ; then
	warn_message_ln "Can not find anatomy file for subject ${subject}. Skipping."
	continue
    else
	if [[ -f ${DATA}/$subject/${subject}_clp+orig.HEAD ]] ; then
	    anatFile=${DATA}/$subject/${subject}_clp+orig.HEAD
	else
	    anatFile=${DATA}/$subject/${subject}+orig.HEAD
	fi
    fi

    if [[ $nonlinear -eq 1 ]] ; then 
	outputScriptName=run/run-afniEmmPreproc-${subject}.${scriptExt}.sh
    else
	outputScriptName=run/run-afniEmmPreproc-${subject}.${scriptExt}.sh	
    fi

    if [[ -f $alignmentParametersShellScriptFile ]] ; then
	info_message_ln "Loading alignment parameters from $alignmentParametersShellScriptFile"
	source $alignmentParametersShellScriptFile
    else
	extraAlignmentArgs="-align_opts_aea -partial_axial"	
	info_message_ln "Setting extra alignment options to default of $extraAlignmentArgs"
    fi  
    
    ## do non-linear warping? If so add the flag to the extra
    ## alignment args variable
    if [[ $nonlinear -eq 1 ]] ; then 
	extraAlignmentArgs="${extraAlignmentArgs} -tlrc_NL_warp"
    fi

    info_message_ln "Writing script: $outputScriptName"

    cat <<EOF > $outputScriptName
#!/bin/bash

set -x 

#$ -S /bin/bash

## disable compression of BRIKs/nii files
unset AFNI_COMPRESSOR

export PYTHONPATH=$AFNI_R_DIR

## use the newer faster despiking method. comment this out to get the
## old one back
export AFNI_3dDespike_NEW=YES

# turn off anoying colorization of info/warn/error messages since they
# only result in gobbledygook
export AFNI_MESSAGE_COLORIZE=NO

## only use a single thread since we're going to run so many subjects
## in parallel
export OMP_NUM_THREADS=${threads}

excessiveMotionThresholdFraction=$excessiveMotionThresholdFraction
excessiveMotionThresholdPercentage=$excessiveMotionThresholdPercentage

cd $DATA/$subject

preprocessingScript=${subject}.afniEmmPreprocess.$scriptExt.csh
rm -f \${preprocessingScript}

outputDir=afniEmmPreprocessed.$scriptExt
rm -fr \${outputDir}

motionThreshold=${motionThreshold}
outlierThreshold=${outlierThreshold}

##	     -tcat_remove_first_trs ${tcat}					\\
## -tlrc_opts_at -init_xform AUTO_CENTER \\
## 	     -regress_censor_outliers \$outlierThreshold                 	\\

## from Helen's modified 3dD script
# -stim_times     1 $DATA/regressors/ml_regressors/1_screen.1D 'SPMG1' 
# -stim_label     1 Screen 
# -stim_times     2 $DATA/regressors/ml_regressors/2_oval.1D 'SPMG1' 
# -stim_label     2 Oval 
# -stim_times_IM  3 $DATA/regressors/ml_regressors/3_neutral_all.1D 'SPMG1' 
# -stim_label     3 Neutral_all 
# -stim_times     4 $DATA/regressors/ml_regressors/4_morph_all.1D 'SPMG1' 
# -stim_label     4 Morph_all 
# -stim_times_IM  5 $DATA/regressors/ml_regressors/5_fear.1D 'SPMG1' 
# -stim_label     5 Fear 
# -stim_times_IM  6 $DATA/regressors/ml_regressors/6_happy.1D 'SPMG1' 
# -stim_label     6 Happy 
# -stim_times_IM  7 $DATA/regressors/ml_regressors/7_sad.1D 'SPMG1' 
# -stim_label     7 Sad 
# -stim_times     8 $DATA/regressors/ml_regressors/8_blank.1D 'SPMG1' 
# -stim_label     8 Blank 

afni_proc.py -subj_id ${subject}										\\
             -script \${preprocessingScript}									\\
	     -out_dir \${outputDir}										\\
	     -blocks tshift align tlrc volreg  mask scale regress						\\
	     -copy_anat $anatFile										\\
	     -dsets $epiFile											\\
	     -tlrc_base MNI_caez_N27+tlrc									\\
	     -volreg_align_to first           									\\
	     -volreg_tlrc_warp	${extraAlignmentArgs}								\\
	     -mask_apply group											\\
	     -regress_stim_times 										\\
	     		$DATA/regressors/ml_regressors/1_screen.1D 						\\
			$DATA/regressors/ml_regressors/2_oval.1D 						\\
			$DATA/regressors/ml_regressors/3_neutral_all.1D 					\\
			$DATA/regressors/ml_regressors/4_morph_all.1D 						\\
			$DATA/regressors/ml_regressors/5_fear.1D 						\\
			$DATA/regressors/ml_regressors/6_happy.1D 						\\
			$DATA/regressors/ml_regressors/7_sad.1D 						\\
			$DATA/regressors/ml_regressors/8_blank.1D 						\\
	     -regress_stim_labels Screen Oval Neutral_all Morph_all Fear Happy Sad Blank			\\
	     -regress_basis 'SPMG1'										\\
	     -regress_stim_types times times IM times IM IM IM times                                            \\
	     -regress_apply_mot_types demean deriv								\\
             -regress_censor_motion \$motionThreshold								\\
	     -regress_censor_outliers \$outlierThreshold							\\
	     -regress_run_clustsim no										\\
	     -regress_est_blur_errts

if [[ -f \${preprocessingScript} ]] ; then 
   tcsh -xef \${preprocessingScript}

    cd \${outputDir}
    xmat_regress=X.xmat.1D 

    if [[ -f \$xmat_regress ]] ; then 

        fractionOfCensoredVolumes=\$( 1d_tool.py -infile \$xmat_regress -show_tr_run_counts frac_cen )
        numberOfCensoredVolumes=\$( 1d_tool.py -infile \$xmat_regress -show_tr_run_counts trs_cen )
        totalNumberOfVolumes=\$( 1d_tool.py -infile \$xmat_regress -show_tr_run_counts trs_no_cen )

        ## rounding method from http://www.alecjacobson.com/weblog/?p=256
        cutoff=\$( echo "((\$excessiveMotionThresholdFraction*\$totalNumberOfVolumes)+0.5)/1" | bc )
	if [[ \$numberOfCensoredVolumes -gt \$cutoff ]] ; then 

	    echo "*** A total of \$numberOfCensoredVolumes of
	    \$totalNumberOfVolumes volumes were censored which is
	    greater than \$excessiveMotionThresholdFraction
	    (n=\$cutoff) of all total volumes of this subject" > \\
		00_DO_NOT_ANALYSE_${subject}_\${excessiveMotionThresholdPercentage}percent.txt

	    echo "*** WARNING: $subject will not be analysed due to having more than \${excessiveMotionThresholdPercentage}% of their volumes censored."
	fi
	
	# make an image to check alignment
	$SCRIPTS_DIR/snapshot_volreg.sh  ${subject}.anat_unif_al_keep+orig  vr_base+orig.HEAD                ${subject}.orig.alignment
	$SCRIPTS_DIR/snapshot_volreg.sh  anat_final.${subject}+tlrc         pb02.${subject}.r01.volreg+tlrc  ${subject}.tlrc.alignment

    else
	touch 00_DO_NOT_ANALYSE_${subject}_\${excessiveMotionThresholdPercentage}percent.txt
    fi
    echo "Compressing BRIKs and nii files"
    find ./ \( -name "*.BRIK" -o -name "*.nii" \) -print0 | xargs -0 gzip
else
    echo "*** No such file \${preprocessingScript}"
    echo "*** Cannot continue"
    exit 1
fi	

EOF

    chmod +x $outputScriptName
    if [[ $enqueue -eq 1 ]] ; then
	info_message_ln "Submitting job for execution to queuing system"
	LOG_FILE=$DATA/$subject/$subject-emm-afniPreproc.${scriptExt}.log
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
