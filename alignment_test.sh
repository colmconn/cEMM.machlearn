#!/bin/bash

set -x 

ROOT=/data/sanDiego/cEMM.machlearn/
SCRIPTS_DIR=${ROOT}/scripts

export PYTHONPATH=/data/software/afni

## use the newer faster despiking method. comment this out to get the
## old one back
export AFNI_3dDespike_NEW=YES

## only use a single thread since we're going to run so many subjects
## in parallel
export OMP_NUM_THREADS=1

subject="$@"

cd /data/sanDiego/cEMM.machlearn/data/${subject}

outputDir=alignmentTest

rm -fr $outputDir

mkdir  $outputDir

cd  $outputDir

cp ../${subject}EMM+orig.* ./

if [[ -f ../${subject}_clp+orig.HEAD ]] ; then
    touch 00_CLIPPED_ANATOMY_USED
    3dcopy ../${subject}_clp+orig.HEAD ${subject}
else
    cp ../${subject}+orig.* ./
fi
anatFile=${subject}+orig.HEAD

## 3dTcat -prefix ${subject}EMM.tcat ${subject}EMM+orig.'[3..$]'
3dcopy ${subject}EMM+orig ${subject}EMM.tcat
## 3dDespike -NEW -nomask -prefix ${subject}EMM.despike ${subject}EMM.tcat+orig.
3dTshift -tzero 0 -quintic -prefix ${subject}EMM.tshift ${subject}EMM.tcat+orig.

epiFile=${subject}EMM.tshift+orig.HEAD						      

if [[ ! -f vr_base+orig.HEAD ]] ; then
    3dbucket -prefix vr_base ${epiFile}\[0\]
fi

epiFile=vr_base+orig.HEAD						      

align_epi_anat.py				\
    -anat ${anatFile}				\
    -epi ${epiFile}				\
    -epi_base 0					\
    -epi_strip 3dAutomask			\
    -giant_move					\
    -volreg off					\
    -tshift off					\
    -partial_axial				\
    -cost lpc					\
    -multi_cost lpa lpc+ZZ mi

3dSkullStrip -orig_vol -input ${anatFile} -prefix ${anatFile%%+*}.ns
3dcalc -a ${anatFile} -b ${anatFile%%+*}.ns+orig -expr "a-b" -prefix ${subject}.anat.ns.diff

epiFile=vr_base+orig.HEAD
for metric in _al _al_lpc+ZZ _al_lpa _al_mi ; do 
    $SCRIPTS_DIR/snapshot_volreg.sh ${subject}${metric}+orig.HEAD vr_base+orig ${subject}${metric}.alignment

    cat_matvec -ONELINE ${subject}${metric}+orig.HEAD'::ALLINEATE_MATVEC_B2S_000000' > ${subject}.anat${metric}_B2S.1D

    3dAllineate -input ${anatFile%%+*}.ns+orig				\
		-prefix ${anatFile%%+*}.ns${metric}			\
		-1Dmatrix_apply ${subject}.anat${metric}_B2S.1D	\
		-final cubic

    3dAllineate -input ${subject}.anat.ns.diff+orig			\
		-prefix ${subject}.anat.ns.diff${metric}		\
		-1Dmatrix_apply ${subject}.anat${metric}_B2S.1D	\
		-final cubic
done

