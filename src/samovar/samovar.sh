#!/usr/bin/env bash
set -eu

#  multivar: T = more than one variable in at least one file , F = only one variable in each file

if [ $# -ne 6 ]
then
  echo wrong number of arguments $#, have to be 6
  echo usage: samovar.sh \<multivar\> \<samovar.csv file\> \<logfile\> \"\<file list\>\" \<cdo binary\> \<samovar executable\>
  exit 1
fi

MULTIVAR=$1
SAMOVAR_CSV=$2
LOGFILE=$3
FILELIST=$4
CDO=$5
SAMOVAR_EXE=$6

export ERRORS=0
if [[ ! -r "${SAMOVAR_CSV}" ]]; then
   echo "Error: '${SAMOVAR_CSV}' is missing or not readable." >> ${LOGFILE}
   exit 1
fi

echo The specified variables are checked for the margins defined in the file ${SAMOVAR_CSV}.  >> ${LOGFILE}

if [ "${MULTIVAR}" == "T" ]
then

  TMP_CDO_INFOV=$(mktemp  tmp_cdo_infov.$$.XXXXXXXXXX)
  TMP_CSV=$(mktemp  tmp.$$.XXXXXXXXXX.csv)

  for FILE in ${FILELIST}
  do
    echo ${FILE} >> ${LOGFILE}
    ${CDO} -s ${INFOV} ${FILE} > ${TMP_CDO_INFOV}
    # cut out the fields 5 (min mean max) and 6 (varname) from "cdo infov" 
    # replace the delimiter ":" by " "
    # condense multiple spaces to one
    # replace " " by "," which transform into csv format
    # remove the first ","
    # in case the whole field has "nan" values, replace "nan" by "-1.E20" otherwise Fortran crashes during read
    # remove all blank lines in the file with grep ..space..
    cut -d : -f 5,6  ${TMP_CDO_INFOV} --output-delimiter=' ' | tr -s ' ' | tr ' ' ',' | cut -c2- | sed 's/nan/-1.E20,-1.E20,-1.E20/g' | grep -v '^[[:space:]]*$' > ${TMP_CSV}
    ${SAMOVAR_EXE} ${SAMOVAR_CSV} ${TMP_CSV} >> ${LOGFILE}
    ERROR_STATUS=$?
    set +e
    if [ ${ERROR_STATUS} -ne 0 ]; then
      ((ERRORS++))
    fi
    set -e
  done

  rm ${TMP_CDO_INFOV} ${TMP_CSV}

else

  TMP_CSV=$(mktemp  tmp.$$.XXXXXXXXXX.csv)

  for FILE in ${FILELIST}
  do
    echo ${FILE} >> ${LOGFILE}

    VAR=$(${CDO} -s showname ${FILE} | sed -e 's/^[ \t]*//')
    echo $(${CDO} -s output -timmin -fldmin -selvar,${VAR} ${FILE}) , -1.E20 , $(${CDO} -s output -timmax -fldmax -selvar,${VAR} ${FILE}) , ${VAR} > ${TMP_CSV}
    ${SAMOVAR_EXE} ${SAMOVAR_CSV} ${TMP_CSV} >> ${LOGFILE}
    ERROR_STATUS=$?
    set +e
    if [ ${ERROR_STATUS} -ne 0 ]; then
      ((ERRORS++))
    fi
    set -e

  done

  rm ${TMP_CSV}

fi

if [ ${ERRORS} -gt 0 ]
then
  exit 1
else
  exit 0
fi
