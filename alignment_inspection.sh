#!/bin/bash

## set -x 

# if ctrl-c is typed exit immediatly
trap die SIGHUP SIGINT SIGTERM

function  die {
    osascript -e 'quit app "Preview"'
    exit
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

SCRIPTS_DIR=$rootDir/sanDiego/$studyName/scripts
DATA=$rootDir/sanDiego/$studyName/data
task=EMM

if [[ $# -gt 0 ]] ; then
    subjects="$*"
else

    ## subjects="$( cat ../data/config/control.subjectList.txt ../data/config/mdd.nat.txt )"
    ## subjects=$( cd /data/sanDiego ; ls -d [0-9][0-9][0-9]_{A,B,C,D,E} [0-9][0-9][0-9]_{A,B,C,D,E}2 2> /dev/null | grep -v 999 )

    subjects=$( cd ../data/ ; ls -d [0-9][0-9][0-9]_{C,D} [0-9][0-9][0-9]_{C,D}2 2> /dev/null | grep -v 999 )    
    
    ## the following is useful if you need to remove the (for example)
    ## first 133 lines because you hit q when you ment to hit the 1
    ## key :-(
    ## subjects=$( cd ../data/ ; ls -d [0-9][0-9][0-9]_A [0-9][0-9][0-9]_A2 2> /dev/null | grep -v 999 | sed -e '1,133d' )
fi

subjectCount=$( echo $subjects | wc -w )

timepointLimiter=followupOnly
shellScriptFile=${SCRIPTS_DIR}/${task}_alignment_parameters.${timepointLimiter}.sh
csvFile=${task}_alignment_parameters.${timepointLimiter}.csv

if [[ -f ${shellScriptFile} ]] ; then
    echo "WARNING: moving pre-existing ${shellScriptFile} to ${shellScriptFile}.orig.$$"
    mv -f ${shellScriptFile} ${shellScriptFile}.orig.$$
fi

echo "Appending the following code to  ${shellScriptFile}"
cat <<EOF | tee ${shellScriptFile}
     case \$subject in
EOF

## sc = subject count
## (( sc=1 ))
(( sc=134 ))
for subject in $subjects ; do
   
    if [[ "x$subject" == "x" ]] ; then
	break
    fi
    echo   "####################################################################################################"
    printf "### Subject: %s (%03d of %03d)\n" $subject $sc $subjectCount
    echo   "####################################################################################################"

    if [[ ! -f $DATA/$subject/${subject}+orig.HEAD ]] || [[ ! -f $DATA/$subject/${subject}${task}+orig.HEAD ]]; then 
	echo "Can't find both T1 anatomy and EPI ${task} state file. Skipping subject"
    else
	( cd $DATA/$subject/alignmentTest && open *.alignment.jpg )
	echo "*** Sleeping for 2 seconds"
	sleep 2
	
	while true ; do
	    echo "Choose from the following list the metric that gave the best alignment, or enter s to skip subject, or q to quit immediately:"
	    echo "	S. Skip this subject"	  
	    echo "	1. LPC    (_al)"
	    echo "	2. LPC+ZZ (_al_lpc+ZZ)"
	    echo "	3. LPA    (_al_lpa)"
	    echo "	4. MI     (_al_mi)"
	    echo "	4. MI     (_al_mi)"
	    echo "	5. UNSURE"
	    echo "	Q or q to quit"	  
	    echo -n "Enter choice: "
	    read choice
	    choice=$( echo "$choice" | tr "[:upper:]" "[:lower:]" )
	    case $choice in
		s*)
		    bestMetric="skip"
		    break
		    ;;
		1*)
		    bestMetric="lpc"
		    break
		    ;;
		2*)
		    bestMetric="lpc+ZZ"		  
		    break
		    ;;
		3*)
		    bestMetric="lpa"		  
		    break
		    ;;
		4*)
		    bestMetric="mi"		  
		    break
		    ;;
		5*)
		    bestMetric="UNSURE"
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

	if [[ $bestMetric != "skip" ]]  ; then 
	    echo "Appending the following code to ${shellScriptFile}"
	    cat <<EOF | tee -a ${shellScriptFile}
	$subject)
	    extraAlignmentArgs="-align_opts_aea  -cost ${bestMetric}"
	    ;;
EOF
	    echo "$subject,${bestMetric}" >> ${csvFile}

	    echo "*** Quitting Preview"
	    osascript -e 'quit app "Preview"'
	else
	    echo "Skipping subject"
	fi

	echo
    fi
    (( sc=sc + 1 ))
done

echo "Appending the following code to ${shellScriptFile}"
cat <<EOF | tee -a ${shellScriptFile}
    	*)
    	    extraAlignmentArgs=""
    	    ;;
    esac
EOF



echo "####################################################################################################"
echo "### All done!"
echo "####################################################################################################"

	# $subject)
	#     doZeropad $subject
	#     anatFile=\${DATA}/processed/\${subject}/\${subject}.anat.zp+orig.HEAD
	#     epiFile=\${DATA}/processed/\${subject}/\${subject}.${task}.zp+orig.HEAD
	#     extraAlignmentArgs="-align_opts_aea  -cost ${bestMetric} -giant_move"
