#!/bin/bash

## set -x 

subjects=$( cd /data/sanDiego/cEMM/data/; find ./ -maxdepth 1 \( -name '[0-9][0-9][0-9]_[ACD]' -o -name '[0-9][0-9][0-9]_[ACD]?' \) -printf "%f " )

for subject in ${subjects} ; do
    if [[ -f /data/sanDiego/cEMM/data/$subject/${subject}EMM+orig.HEAD ]] \
	   && [[ -f /data/sanDiego/cEMM/data/$subject/${subject}+orig.HEAD ]] ; then

	echo "*** Copying anatomy and EMM files for $subject"
	
	mkdir ../data/$subject
	(cd ../data/$subject ; cp -a /data/sanDiego/cEMM/data/$subject/${subject}EMM+orig.* /data/sanDiego/cEMM/data/$subject/${subject}+orig.* ./ )

    fi
done
	       
	    
