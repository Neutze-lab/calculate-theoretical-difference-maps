#!/bin/sh
##################################################
#
# (c) 2020 Cecilia Wickstrand @NeutzeLab
# Modified by Adams Vallejos <adams.vallejos@gu.se>
# Version: 19 OCT 2020
#
##################################################
# REQUIREMENTS: CCP4 suite: sfall, cad, mtz2various, fft
# USAGE : sh calculateTheoreticalDifferenceMaps.sh
# 
# Input files have full occupancy 

# INPUT
#----------------------------------------------------------------------------
# inputDirectory='/absolute/path/to/folder/with/PDBs
inputDirectory='/home/adams/data_proc/theoreticalDifferenceMaps'

# RUN 1  Ground state
groundStatePDB='5b6v.pdb'
nameOfGroundState='5b6v'
# outputDirectory='/absolute/path/to/folder/with/PDBs/output
outputDirectory='/home/adams/data_proc/theoreticalDifferenceMaps/output'

lowResolution=100
highResolution=1.7
symmetryNumber=173 # space group = P 63

# CALCULATE STRUCTURE FACTORS (theoretical F_hkl, PHI_hkl)
#----------------------------------------------------------------------------
structureFactorsDirectory=$outputDirectory/sfs
logDirectory=$outputDirectory/log
mkdir $outputDirectory
mkdir $structureFactorsDirectory
mkdir $logDirectory

# ground state
sfall HKLOUT $structureFactorsDirectory/sf_$nameOfGroundState.mtz  XYZIN  $inputDirectory/$groundStatePDB <<END-sfall > $structureFactorsDirectory/sf_$nameOfGroundState.log
TITL Phasing on groundStatePDB state structure: $inputDirectory/$groundStatePDB
SYMM $symmetryNumber
MODE SFCALC XYZIN 
RESO $lowResolution $highResolution 
LABO FC=F_g0 PHIC=PHI_g0
end 
END-sfall

echo "structure factors of ground state completed"

# loop through the excited states
cd $inputDirectory
# Ugly way to not loop through first file
mv $nameOfGroundState'.pdb' $nameOfGroundState'.tmp'
for pdbE in *.pdb
do
nameE=${pdbE%.pdb} 
echo "Working on file $nameE $pdbE"

# pdbE state
sfall HKLOUT $structureFactorsDirectory/sf_$nameE.mtz  XYZIN  $inputDirectory/$pdbE <<END-sfall > $structureFactorsDirectory/sf_$nameE.log
TITL Phasing on pdbE state structure: $inputDirectory/$pdbE
SYMM $symmetryNumber
MODE SFCALC XYZIN 
RESO $lowResolution $highResolution 
LABO FC=F_e0 PHIC=PHI_e0
end 
END-sfall
    
echo "structure factors of $nameE completed"


# Merge the two datasets
cad hklin1 $structureFactorsDirectory/sf_$nameOfGroundState.mtz hklin2 $structureFactorsDirectory/sf_$nameE.mtz \
hklout $structureFactorsDirectory/sf_$nameOfGroundState_$nameE.mtz << EOF > $structureFactorsDirectory/sf_$nameOfGroundState_$nameE.log
RESOLUTION OVERALL $lowResolution $highResolution
SYMMETRY $symmetryNumber
TITLE Merging the data sets
LABIN FILE 1 ALL
LABIN FILE 2 ALL 
END
EOF

mtz2various HKLIN $structureFactorsDirectory/sf_$nameOfGroundState_$nameE.mtz HKLOUT $structureFactorsDirectory/sf_$nameOfGroundState_$nameE.dat << EOF >> $structureFactorsDirectory/sf_$nameOfGroundState_$nameE.log
RESOLUTION 10000 0
OUTPUT USER *
LABIN DUM1=F_g0 DUM2=F_e0 DUM3=PHI_g0 DUM4=PHI_e0
END
EOF

echo "Merging completed"


# CALCULATE MAP
#----------------------------------------------------------------------------
fft hklin $structureFactorsDirectory/sf_$nameOfGroundState_$nameE.mtz  mapout $outputDirectory/$nameE'_'$nameOfGroundState.map << EOF-map > $logDirectory/$nameE'_'$nameOfGroundState.log
title w(Fc - Fc) map of $inputDirectory/$groundStatePDB + $pdbE
labin  F1=F_e0 \
       	       F2=F_g0 PHI=PHI_g0
EOF-map

echo "Map calculation completed"

done

mv $nameOfGroundState'.tmp' $nameOfGroundState'.pdb' 
exit

# CONTROL AND CLEANING UP (create or remove control files)
#----------------------------------------------------------------------------

# # write out read-able version of the original mtz files
# 
# mtzdump HKLIN $structureFactorsDirectory/sf_groundStatePDB.mtz  <<EOF> $structureFactorsDirectory/sf_groundStatePDB.txt 
# NREF -1
# EOF
#
# mtzdump HKLIN $structureFactorsDirectory/sf_pdbE.mtz <<EOF> $structureFactorsDirectory/sf_pdbE.txt
# NREF -1
# EOF
#
# mtzdump HKLIN $structureFactorsDirectory/sf_merged.mtz <<EOF> $structureFactorsDirectory/sf_merged.txt
# NREF -1
# EOF


# # Remove unnecessary files (comment on/off to keep control)
rm $structureFactorsDirectory/sf_groundStatePDB.mtz
rm $structureFactorsDirectory/sf_pdbE.mtz
# rm $structureFactorsDirectory/sf_groundStatePDB.log
# rm $structureFactorsDirectory/sf_pdbE.log
rm $structureFactorsDirectory/sf_merged.log
# rm $outputDirectory/$name.log