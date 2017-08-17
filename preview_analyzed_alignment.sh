#!/bin/bash

## set -x 

programName=`basename $0`

# if ctrl-c is typed exit immediatly
trap die SIGHUP SIGINT SIGTERM

function  die {
    osascript -e 'quit app "Preview"'
    exit
}


function ask_for_quality {

    local __quality=$1
    while true ; do
	echo "Choose from the following list the metric that gave the best alignment, or enter s to skip subject, or q to quit immediately:"
	echo "	S. Skip this subject"	  
	echo "	G. GOOD"
	echo "	B. BAD"
	echo "	U. UNSURE"	
	echo "	Q or q to quit"	  
	echo -n "Enter choice: "
	read choice
	choice=$( echo "$choice" | tr "[:upper:]" "[:lower:]" )
	case $choice in
	    s*)
		quality="skip"
		break
		;;
	    g*)
		quality="good"
		break
		;;
	    b*)
		quality="bad"		  
		break
		;;
	    u*)
		quality="unsure"		  
		break
		;;
	    q*)
		die
		break
		;;
	    *)
		echo "Unknown choice ($choice). Try again."
		;;
	esac
    done
    eval $__quality="'$quality'"
}

function check_for_do_not_analyze {

    local subject=$1

    if [[ -f $PROCESSED_DATA/${subject}/00_DO_NOT_ANALYSE_${subject}_20percent.txt ]] ; then
	echo "*** Subject had to much censored data"
    fi
    if [[ -f $PROCESSED_DATA/${subject}/3dDeconvolve.err ]] ; then
	cat $PROCESSED_DATA/${subject}/3dDeconvolve.err
    fi
    
}

studyName=cEMM.machlearn

if [[ $( uname -s) == "Darwin" ]] ; then
    rootDir="/Volumes/data"
elif [[ $( uname -s) == "Linux" ]] ; then
    rootDir="/data"
    echo "*** Sorry this program is not yet set up to run on Linux. Run it on a MAC"
    exit 1
else 
    echo "Sorry can't set data directories for this computer"
    exit 1
fi

GETOPT=$( which getopt )
SCRIPTS_DIR=$rootDir/sanDiego/$studyName/scripts
DATA=$rootDir/sanDiego/$studyName/data

task=EMM

alignment_dir=afniEmmPreprocessed.NL

GETOPT_OPTIONS=$( $GETOPT \
		      -o "om" \
		      --longoptions "orig,mni" \
		      -n ${programName} -- "$@" )
exitStatus=$?
if [ $exitStatus != 0 ] ; then 
    echo "Error with getopt. Terminating..." >&2 
    exit $exitStatus
fi

## 1 = force creation of zero padded files
force=0

## show the original space overlay
seeOrigOverlay=0
## see the MNI space overlay
seeMniOverlay=0

# Note the quotes around `$GETOPT_OPTIONS': they are essential!
eval set -- "$GETOPT_OPTIONS"
while true ; do 
    case "$1" in
	-o|--orig)
	    seeOrigOverlay=1; shift 1;;
	-m|--mni)
	    seeMniOverlay=1; shift 1 ;;	
	--) 
	    shift ; break ;;

	*) 
	    echo "${programName}: ${1}: invalid option" >&2
	    exit 2 ;;
    esac
done

if [[ $seeOrigOverlay -eq 0 ]] && [[ $seeMniOverlay -eq 0 ]] ; then
    echo "*** Nothing to see here! seeOrigOverlay and seeMniOverlay are both 0!"
    exit 1
fi

if [[ $# -gt 0 ]] ; then
    subjects="$*"
else

    ## subjects=$( cd ../data/ ; ls -d [0-9][0-9][0-9]_A [0-9][0-9][0-9]_A2 2> /dev/null | grep -v 999 )
    subjects=$( cd ../data/ ; ls -d [0-9][0-9][0-9]_{C,D} [0-9][0-9][0-9]_{C,D}2 2> /dev/null | grep -v 999 ) 
fi

subjectCount=$( echo $subjects | wc -w )

timepointLimiter=followupOnly
qualityFile=${SCRIPTS_DIR}/${task}_alignment_quality.${timepointLimiter}.csv

if [[ -f ${SCRIPTS_DIR}/${qualityFile} ]] ; then
    echo "WARNING: moving pre-existing ${qualityFile} to ${qualityFile}.orig.$$"
    mv -f ${qualityFile} ${qualityFile}.orig.$$
fi

echo "subject,space,quality" > $qualityFile

## sc = subject count
(( sc=1 )) 
for subject in $subjects ; do
   
    if [[ "x$subject" == "x" ]] ; then
	break
    fi
    echo   "####################################################################################################"
    printf "### Subject: %s (%03d of %03d)\n" $subject $sc $subjectCount
    echo   "####################################################################################################"

    if [[ ! -f $DATA/$subject/${subject}+orig.HEAD ]] || [[ ! -f $DATA/$subject//${subject}${task}+orig.HEAD ]]; then 
	echo "Can't find both T1 anatomy and EPI ${task} state file. Skipping subject"
    else

	if [[ $seeOrigOverlay == 1 ]] ; then
	    ## original space overlay
	    
	    if [[ -f $DATA/$subject/${alignment_dir}/$subject.orig.alignment.jpg ]] ; then 
		( cd $DATA/$subject/${alignment_dir} && open $subject.orig.alignment.jpg )
		echo "*** Sleeping for 1 seconds"
		sleep 1

		quality=''
		ask_for_quality quality

		if [[ $quality != "skip" ]]  ; then 
		    echo "$subject,ORIG,${quality}" >> ${qualityFile}

		    echo "*** Quitting Preview"
		    osascript -e 'quit app "Preview"'
		else
		    echo "Skipping subject"
		fi
	    else
		echo "$subject,ORIG,NO_JPEG" >> ${qualityFile}
	    fi
	fi
	
	if [[ $seeMniOverlay == 1 ]] ; then 
	    ## MNI space overlay

	    if [[ -f $DATA/$subject/${alignment_dir}/$subject.tlrc.alignment.jpg ]] ; then 
		( cd $DATA/$subject/${alignment_dir} && open $subject.tlrc.alignment.jpg )
		echo "*** Sleeping for 1 seconds"
		sleep 1
		
		quality=''
		ask_for_quality quality
		
		if [[ $quality != "skip" ]]  ; then 
		    echo "$subject,MNI,${quality}" >> ${qualityFile}
		    
		    echo "*** Quitting Preview"
		    osascript -e 'quit app "Preview"'
		else
		    echo "Skipping subject"
		fi
	    else
		echo "$subject,MNI,NO_JPEG" >> ${qualityFile}
	    fi
	fi
	echo
    fi
    (( sc=sc + 1 ))
done

echo "####################################################################################################"
echo "### All done!"
echo "####################################################################################################"
