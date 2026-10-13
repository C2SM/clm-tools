# ICON-CLM Starter Package (SPICE_v2.4)
#
# ---------------------------------------------------------------
# Copyright (C) 2009-2026, Helmholtz-Zentrum Hereon
# Contact information: https://www.clm-community.eu/
#
# See AUTHORS.TXT for a list of authors
# See LICENSES/ for license information
# SPDX-License-Identifier: GPL-3.0-or-later
#
# SPICE docs: https://hereon-coast.atlassian.net/wiki/spaces/SPICE/overview
# ---------------------------------------------------------------

################################################################################
#   Functions used in the chain scripts:
################################################################################


################################################################################
# 1. extract_gcm_data
#
# Extracts monthly GCM input data for different datasets into the working
# directory, handling dataset-specific formats and temporal sub-sampling.
#
# Supported datasets:
#   ERAINT  - ERA-Interim monthly archives
#   ERA5    - ERA5 monthly archives (hourly or sub-sampled by HINCBOUND)
#   CMIP6   - CMIP6 GCM archives
#   JRA55   - JRA55 data copied and converted via nccopy
#   MERRA2  - MERRA2 monthly archives
#
# Arguments:
#   DATASET   Dataset identifier (ERAINT, ERA5, CMIP6, JRA55, MERRA2)
#   YYYY      4-digit year
#   MM        2-digit month
#   INPDIR    Target input directory for extracted files
#   HINCBOUND Hour increment for ERA5 sub-sampling (01,02,03,04,06)
#
# Required external variables:
#   GCM_DATADIR     Root directory of archived GCM data
#   GCM_PREFIX      Filename prefix for GCM files (e.g. caf, cas, etc.)
#   GCM_NAME        CMIP6 model name (used for CMIP6 only)
#   GCM_SCENARIO    CMIP6 scenario identifier (used for CMIP6 only)
#   YYYY_MM         Year-month string (YYYY_MM) for JRA55 paths
#   OUTDIR          Target output directory for processed JRA55 files
#   NC_BINDIR       Path to NetCDF utilities (nccopy)
#   MAXPP           Maximum number of parallel processes
#
# Required helper functions:
#   run_parallel_throttle   Controls parallel job submission
#   wait_or_fail            Waits for jobs and aborts on failure
#
# Returns:
#   0 on success, 1 on failure
#
################################################################################
extract_gcm_data() {
  local DATASET="$1"
  local YYYY="$2"
  local MM="$3"
  local INPDIR="$4"
  local HINCBOUND="$5"

  local TARFILE

  case "${DATASET}" in
    ERAINT)
      TARFILE="${GCM_DATADIR}/year${YYYY}/ERAINT_${YYYY}_${MM}.tar"
      [[ -f "${TARFILE}" ]] || { echo "ERROR: Missing archive: ${TARFILE}" >&2; return 1; }
      echo "    INFO: Extracting ERA-Interim ${YYYY}-${MM}"
      tar -C "${INPDIR}/${YYYY}_${MM}" -xf "${TARFILE}" || return 1
      ;;

    ERA5)
      TARFILE="${GCM_DATADIR}/year${YYYY}/ERA5_${YYYY}_${MM}.tar"
      [[ -f "${TARFILE}" ]] || { echo "ERROR: Missing archive: ${TARFILE}" >&2; return 1; }
      echo "    INFO: Extracting ERA5 ${YYYY}-${MM} (HINCBOUND=${HINCBOUND})"
      case "$(printf %02d ${HINCBOUND})" in
        01)
          echo "    INFO: Extracting ERA5 hourly"
          tar -C "${INPDIR}" -xvf "${TARFILE}" || return 1
          ;;

        02|03|04|06)
          echo "    INFO: Extracting ERA5 every ${HINCBOUND} hours"
          COUNTPP=0
          for (( HOUR=0; HOUR<=23; HOUR+=HINCBOUND )); do
            NCZ_FILES="${YYYY}_${MM}/${GCM_PREFIX}*$(printf %02d ${HOUR}).ncz"
            tar --wildcards -C "${INPDIR}" -xvf "${TARFILE}" "${NCZ_FILES}" &
            run_parallel_throttle
          done
          wait_or_fail "ERA5_UNTAR"
          ;;
        *)
          echo "ERROR: Invalid HINCBOUND=${HINCBOUND} for ERA5 (must be 01,02,03,04,06)" >&2
          return 1;;
      esac
      ;;

    CMIP6)
      : "${GCM_NAME:?ERROR: GCM_NAME must be set for CMIP6}"
      : "${GCM_SCENARIO:?ERROR: GCM_SCENARIO must be set for CMIP6}"

      TARFILE="${GCM_DATADIR}/year${YYYY}/${GCM_NAME}_${GCM_SCENARIO}_${YYYY}_${MM}.tar"
      [[ -f "${TARFILE}" ]] || { echo "ERROR: Missing archive: ${TARFILE}" >&2; return 1; }
      echo "    INFO: Extracting CMIP6 data: ${GCM_NAME}_${GCM_SCENARIO}_${YYYY}_${MM}"
      tar -C "${INPDIR}/${YYYY}_${MM}" -xf "${TARFILE}" || return 1
      ;;

    JRA55)
      echo "    INFO: Extracting JRA55 data:"
      : "${OUTDIR:?ERROR: OUTDIR must be set for JRA55}"

      shopt -s nullglob
      local files=( "${INPDIR}/${YYYY_MM}"/* )

      if (( ${#files[@]} == 0 )); then
        echo "WARNING: No JRA55 files found in ${INPDIR}/${YYYY_MM}"
      fi

      COUNTPP=0
      for FILE in "${files[@]}"; do
        FILEIN=$(basename "${FILE}")
        FILEOUT="${FILEIN}"
        "${NCCOPY[@]}" -k 2 "${INPDIR}/${YYYY_MM}/${FILEIN}" "${OUTDIR}/${YYYY_MM}/${FILEOUT}" &
        run_parallel_throttle
      done
      shopt -u nullglob
      wait_or_fail "JRA55_UNTAR"
      #rm -rf ${INPDIR}/${YYYY_MM}
      ;;

    MERRA2)
      TARFILE="${GCM_DATADIR}/MERRA2_${YYYY}_${MM}.tar"
      [[ -f "${TARFILE}" ]] || { echo "ERROR: Missing archive: ${TARFILE}" >&2; return 1; }
      echo "    INFO: Extracting MERRA2 data: ${TARFILE}"
      tar -C "${INPDIR}" -xf "${TARFILE}" || return 1
      ;;

    *)
      echo "ERROR: Unknown DATASET=${DATASET}" >&2
      return 1
      ;;
  esac
}


################################################################################
# 2. set_unzip_filenames
# Derive input/output filenames for UNZIP stage based on dataset
#
# Sets two global variables:
#   FILEIN   - input filename relative to INPDIR/YYYY_MM
#   FILEOUT  - output filename relative to OUTDIR/YYYY_MM
################################################################################
set_unzip_filenames() {
  local DATASET="$1"
  local FILE="$2"

  case "${DATASET}" in
    JRA55|MERRA2)
      FILEIN=$(basename "${FILE}")
      FILEOUT="${FILEIN}"
      ;;
    *)
      FILEBASE=$(basename "${FILE}" .ncz)
      FILEIN="${FILEBASE}.ncz"
      FILEOUT="${FILEBASE}.nc"
      ;;
  esac
}

################################################################################
# 3. get_ccaf2icaf_args
#
# Determines the ccaf2icaf argument signature based on dataset.
#
# Arguments:
#   DATASET  Dataset identifier (ERAINT, ERA5, CMIP6, JRA55, MERRA2)
#
# Output:
#   Echoes the argument string to stdout (to be captured by caller)
#
################################################################################
get_ccaf2icaf_args() {
  local DATASET="$1"

  case "${DATASET}" in
    ERAINT)
      echo "1";;
    ERA5)
      : "${GCM_SOILTYPE:?ERROR: GCM_SOILTYPE must be set for ERA5}"
      echo "2 ${GCM_SOILTYPE}";;
    CMIP6|JRA55|MERRA2)
      echo "0";;
    *)
      echo "ERROR: Unsupported dataset for ccaf2icaf: ${DATASET}" >&2
      return 1;;
  esac
}

################################################################################
# 4. extract_icon_input_archives
#
# Extract ICON input archives using dataset-specific rules.
# ERA5 uses wildcard extraction; other datasets use standard tar.
#
# Uses global variables:
#   OUTDIR, YYYY_MM, INIDIR, CURRENT_DATE, YDATE_START
################################################################################
extract_icon_input_archives() {
  local DATASET="$1"
  local ARCH_MAIN="$2"
  local ARCH_INI="$3"

  case "${DATASET}" in
    ERA5)
      echo "    INFO: Using wildcard extraction for ERA5"
      tar --wildcards -C "${OUTDIR}/${YYYY_MM}" -xf "${ARCH_MAIN}" || return 1
      if [ "${CURRENT_DATE}" -eq "${YDATE_START}" ]; then
        tar --wildcards -C "${INIDIR}" -xf "${ARCH_INI}" || return 1
      fi
      ;;

    ERAINT|CMIP6|JRA55|MERRA2)
      echo "    INFO: Using standard extraction for ${DATASET}"
      tar -C "${OUTDIR}/${YYYY_MM}" -xf "${ARCH_MAIN}" || return 1
      if [ "${CURRENT_DATE}" -eq "${YDATE_START}" ]; then
        tar -C "${INIDIR}" -xf "${ARCH_INI}" || return 1
      fi
      ;;

    *)
      echo "ERROR: Unsupported dataset for ICON input copy: ${DATASET}" >&2
      return 1;;
  esac
}

################################################################################
# 5. run_parallel_throttle
#
# Limits the number of concurrently running background jobs to MAXPP.
#
# This function must be called immediately after launching a background job (&).
# It increments a global counter (COUNTPP) and triggers a blocking wait when the
# number of parallel jobs reaches MAXPP.
#
# Globals used:
#   COUNTPP   - current number of running jobs in this batch
#   MAXPP     - maximum number of parallel jobs allowed
#
# Behavior:
#   - Increments COUNTPP
#   - If COUNTPP >= MAXPP:
#       * waits for all running background jobs to finish
#       * resets COUNTPP to 0
#
# Example usage:
#   some_command &
#   run_parallel_throttle
#
################################################################################
run_parallel_throttle() {
    (( COUNTPP=COUNTPP+1 ))
    if [[ ${COUNTPP} -ge ${MAXPP} ]]; then
        COUNTPP=0
        wait
    fi
}

################################################################################
# 6. wait_or_fail
#
# Waits for all currently running background jobs and aborts if any failed.
#
# This function must be called after launching a batch of background jobs
# (typically after using run_parallel_throttle) to ensure that all parallel
# processes have completed successfully.
#
# If any background job exits with a non-zero status, this function:
#   - prints a clear error message including the processing phase
#   - instructs the user where to find detailed logs
#   - terminates the script with exit code 1
#
# If all background jobs succeed, it prints a success message for the phase.
#
# Arguments:
#   PHASE     - descriptive name of the current processing phase
#               (e.g. "COMPRESSION", "CF_CORRECTION", "TAR_ARCHIVE")
#
# Globals used:
#   (none directly, but relies on background jobs started in the current shell)
#
# Behavior:
#   - Calls wait to block until all background jobs complete
#   - On success:
#       * prints an INFO message for the phase
#   - On failure:
#       * prints an ERROR message for the phase
#       * advises checking chain_status.log and job logs
#       * exits the script with code 1
#
# Example usage:
#   some_parallel_command &
#   run_parallel_throttle
#   ...
#   wait_or_fail "COMPRESSION"
#
################################################################################
wait_or_fail() {
  local PHASE="$1"
  if wait; then
    echo "    INFO: ${PHASE} completed successfully"
  else
    echo "ERROR: One or more background jobs failed during ${PHASE}" >&2
    echo "       Check chain_status.log and job logs for details." >&2
    exit 1
  fi
}

################################################################################
# 7. count_level_files
#
# Estimates the number of output files that will be produced by a list of
# timeseries commands using symbolic level arrays (PLEVS, ZLEVS, HLEVS).
#
# For each command passed:
#   - If it references PLEVS, adds number of pressure levels
#   - If it references ZLEVS, adds number of z-levels
#   - If it references HLEVS, adds number of height levels
#
# This is used to predict the total number of output files for progress
# reporting or validation.
#
# Arguments:
#   List of timeseries command strings
#
# Globals used:
#   PLEVS, ZLEVS, HLEVS - level arrays
#   NUMFILES          - incremented by this function
#
# Example:
#   NUMFILES=0
#   count_level_files "${ts_command_list[@]}"
#
################################################################################
count_level_files() {
  local ts_command
  for ts_command in "$@"; do
    if grep -q 'PLEVS' <<< "${ts_command}"; then
      NUMFILES=$((NUMFILES + ${#PLEVS[@]}))
    elif grep -q 'ZLEVS' <<< "${ts_command}"; then
      NUMFILES=$((NUMFILES + ${#ZLEVS[@]}))
    elif grep -q 'HLEVS' <<< "${ts_command}"; then
      NUMFILES=$((NUMFILES + ${#HLEVS[@]}))
    fi
  done
}


################################################################################
# 8. notify_finish_message
#
# Prints a completion message and optionally sends a notification email.
#
# If NOTIFICATION_ADDRESS is defined, the message is written to a temporary file
# and sent via NOTIFICATION_SCRIPT.
#
# Arguments:
#   $1 - Message text to be printed and sent
#
# Globals used:
#   NOTIFICATION_ADDRESS  - recipient email address (optional)
#   NOTIFICATION_SCRIPT  - script used to send notifications
#   PFDIR, EXPID         - used for temporary message storage
#
# Example:
#   notify_finish_message "Postprocessing finished successfully."
#
################################################################################
notify_finish_message() {
  local MSG="$1"
  echo "${MSG}"
  if [[ -n "${NOTIFICATION_ADDRESS}" ]]; then
    echo "${MSG}" > "${PFDIR}/${EXPID}/finish_message"
    "${NOTIFICATION_SCRIPT}" "${NOTIFICATION_ADDRESS}" "ICON-CLM ${EXPID} job finished" \
      "${PFDIR}/${EXPID}/finish_message"
  fi
}


################################################################################
# 9. notify_error_message
#
# Prints an error message and optionally sends a notification email indicating
# that the postprocessing chain aborted due to errors.
#
# If NOTIFICATION_ADDRESS is defined, the message is written to a temporary file
# and sent via NOTIFICATION_SCRIPT.
#
# Arguments:
#   $1 - Error message text
#
# Globals used:
#   NOTIFICATION_ADDRESS  - recipient email address (optional)
#   NOTIFICATION_SCRIPT  - script used to send notifications
#   PFDIR, EXPID         - used for temporary message storage
#
# Example:
#   notify_error_message "Error in post: Missing input files for 1980_02"
#
################################################################################
notify_error_message() {
  local MSG="$1"
  echo "${MSG}"
  if [[ -n "${NOTIFICATION_ADDRESS}" ]]; then
    echo "${MSG}" > "${PFDIR}/${EXPID}/error_message"
    "${NOTIFICATION_SCRIPT}" "${NOTIFICATION_ADDRESS}" \
      "SUBCHAIN ${EXPID} abort due to errors in post" "${PFDIR}/${EXPID}/error_message"
    rm -f "${PFDIR}/${EXPID}/error_message"
  fi
}

################################################################################
# 10. notify_message_file
#
# Sends a notification using an existing message file.
#
# Arguments:
#   $1 - Subject
#   $2 - Message file
#
# Globals used:
#   NOTIFICATION_ADDRESS
#   NOTIFICATION_SCRIPT
#
################################################################################
notify_message_file() {
  local SUBJECT="$1"
  local MESSAGE_FILE="$2"

  if [ -n "${NOTIFICATION_ADDRESS}" ] && [ -f "${MESSAGE_FILE}" ]; then
    "${NOTIFICATION_SCRIPT}" "${NOTIFICATION_ADDRESS}" \
      "${SUBJECT}" "${MESSAGE_FILE}"
  fi
}

################################################################################
# 11. measure_time
#
# Computes elapsed time in seconds relative to a reference timestamp and stores
# the result in a specified variable.
#
# By default, the reference timestamp is DATE1 (step timing). In this case,
# DATE1 is updated to the current time after the measurement. A different
# reference (e.g., DATE_START) can be provided for total timing; in that case,
# the reference variable is not modified.
#
# Arguments:
#   $1 - Name of variable to store elapsed time (e.g., SEC_UNTAR)
#   $2 - (Optional) Name of reference time variable (default: DATE1)
#
# Globals used:
#   DATE1   - updated when used as reference
#   PYTHON  - Python command array for arithmetic
#
# Example:
#   measure_time SEC_UNTAR              # time since last step
#   measure_time SEC_TOTAL DATE_START   # total time since start
#
################################################################################
measure_time() {
  local __resultvar="$1"
  local __refvar="${2:-DATE1}"   # default reference is DATE1

  local DATE2
  DATE2=$(date +%s)

  # indirect expansion to get value of reference variable
  local REF_TIME="${!__refvar}"

  local DELTA=$("${PYTHON[@]}" -c "print(${DATE2}-${REF_TIME})")

  # update DATE1 only if it is used as reference
  if [[ "${__refvar}" == "DATE1" ]]; then
    DATE1=${DATE2}
  fi

  printf -v "${__resultvar}" '%s' "${DELTA}"
}

#-------------------------------------------------------------------------------
# 12. select_compression
# Purpose : Set compression parameters based on config value
# Usage   : select_compression <mode> <itype>
# Example : select_compression POST "${ITYPE_COMPRESS_POST}"
#           select_compression ARCH "${ITYPE_COMPRESS_ARCH}"
#-------------------------------------------------------------------------------
select_compression() {
  local MODE="$1"      # e.g. POST or ARCH
  local ITYPE="$2"     # compression selector value

  local TYPE_VAR="${MODE}_COMPRESS_TYPE"
  local SUFFIX_VAR="${MODE}_FORMAT_SUFFIX"
  local PAR_VAR="${MODE}_PARALLEL_MODE"

  if [[ ! "${MODE}" =~ ^(POST|ARCH)$ ]]; then
    echo "ERROR: Invalid MODE passed to select_compression: ${MODE}"
    exit 1
  fi

  case "${ITYPE}" in
    0)
      echo "**** ${MODE}: no compression ****"
      eval "${TYPE_VAR}=none"
      eval "${SUFFIX_VAR}=nc"
      eval "${PAR_VAR}=1";;
    1)
      echo "**** ${MODE}: internal netCDF compression ****"
      eval "${TYPE_VAR}=nccopy"
      eval "${SUFFIX_VAR}=ncz"
      eval "${PAR_VAR}=1";;
    2)
      echo "**** ${MODE}: gzip compression ****"
      eval "${TYPE_VAR}=gzip"
      eval "${SUFFIX_VAR}=gz"
      eval "${PAR_VAR}=1";;
    3)
      echo "**** ${MODE}: pigz compression ****"
      eval "${TYPE_VAR}=pigz"
      eval "${SUFFIX_VAR}=gz"
      eval "${PAR_VAR}=0";;
    *)
      echo "ERROR: Invalid value for ITYPE_COMPRESS_${MODE}: ${ITYPE}"
      echo "       Allowed values:"
      echo "         0 = no compression"
      echo "         1 = nccopy"
      echo "         2 = gzip"
      echo "         3 = pigz"
      echo "       No compression applied."
      eval "${TYPE_VAR}=none"
      eval "${SUFFIX_VAR}=nc"
      eval "${PAR_VAR}=1";;
  esac
}


#########################################################
#... function for correcting CDO created netCDF
#########################################################
function cdocor {
  # CALL: inparameter infile outparameter outfile

  inparameter=$1
  infile=$2
  outparameter=$3
  outfile=$4

  #... set the _FillValue to -1.E20
  set +e
  fillvalue=$("${NCDUMP[@]}" -h ${outfile} | grep ${outparameter}:_FillValue)
  if [ "${fillvalue}" ]
  then
    "${CDO[@]}" -s setmissval,-1.E20 ${outfile} ${outfile}_tmp${EXPID}${YYYY}${MM}
    mv ${outfile}_tmp${EXPID}${YYYY}${MM} ${outfile}
  fi
  set -e
  # get the coordinates from the original file
  COORDINATES=$("${NCDUMP[@]}" -h ${infile} | grep ${inparameter}:coordinates | cut -d'"' -f2)
  # only if coordinates exists a correction is necessary
  if [ "${COORDINATES}" ]
  then
    "${NCATTED[@]}" -h -a coordinates,${outparameter},o,c,"${COORDINATES}" ${outfile}
    # if the rotated_pole variable exists exclude it from the copy list
    "${NCDUMP[@]}" -h ${outfile} | grep "rotated_pole ;" > /dev/null
    if [ $? -ne 0 ]
    then
      COORDINATES=$(echo ${COORDINATES} | tr ' ' ','),rotated_pole
    else
      COORDINATES=$(echo ${COORDINATES} | tr ' ' ',')
    fi
    # copy coordinates from old to new file
    "${NCKS[@]}" -h -A -C -v ${COORDINATES} ${infile} ${outfile}
  fi
}

#########################################################
#... function for correcting ICON output regarding CF conventions
#########################################################
function iconcor {
  COUNT=$1
  INC=$2
  FILE=$3
  OPER=$4

  if [ $(echo ${FILE} | rev | cut -c -4 | rev) == 'p.nc' ]
  then
      "${NCRENAME[@]}" -h -d plev,pressure -v plev,pressure ${FILE} > /dev/null
  fi

  if [ $(echo ${FILE} | rev | cut -c -4 | rev) == 'z.nc' ]
  then
    if [ "$("${NCDUMP[@]}" -h ${FILE} | grep 'altitude')" != "" ]
    then
      "${NCRENAME[@]}" -h -d alt,altitude -v alt,altitude ${FILE} > /dev/null
      "${NCAP2[@]}" -h -O -s 'altitude=float(altitude)' ${FILE} tmp${EXPID}${YYYY}${MM}${COUNT}.nc
      cp tmp${EXPID}${YYYY}${MM}${COUNT}.nc ${FILE}
      rm tmp${EXPID}${YYYY}${MM}${COUNT}.nc
    fi
  fi

#... in case of runoff_s or runoff_g remove the dimension depth
  if [ "$("${NCDUMP[@]}" -h ${FILE} | grep 'runoff_s_t_8')" != "" ]
  then
    DEPTH=$("${NCDUMP[@]}" -h ${FILE} | grep time\,\ depth | grep runoff_s_t_8 | cut -d, -f 2) ; DEPTH=$(echo ${DEPTH##*( )})
    "${NCWA[@]}" -h -O --no_cell_methods -a ${DEPTH} ${FILE} tmp${EXPID}${YYYY}${MM}${COUNT}.nc
    "${NCKS[@]}" -h -O -x -v ${DEPTH},${DEPTH}_bnds tmp${EXPID}${YYYY}${MM}${COUNT}.nc ${FILE}
    rm tmp${EXPID}${YYYY}${MM}${COUNT}.nc
  elif [ "$("${NCDUMP[@]}" -h ${FILE} | grep 'runoff_s')" != "" ] ; then
    DEPTH=$("${NCDUMP[@]}" -h ${FILE} | grep time\,\ depth | grep runoff_s | cut -d, -f 2) ; DEPTH=$(echo ${DEPTH##*( )})
    "${NCWA[@]}" -h -O --no_cell_methods -a ${DEPTH} ${FILE} tmp${EXPID}${YYYY}${MM}${COUNT}.nc
    "${NCKS[@]}" -h -O -x -v ${DEPTH},${DEPTH}_bnds tmp${EXPID}${YYYY}${MM}${COUNT}.nc ${FILE}
    "${NCATTED[@]}" -h -a cell_methods,runoff_s,o,c,'time: sum' ${FILE}
    rm tmp${EXPID}${YYYY}${MM}${COUNT}.nc
  fi
  if [ "$("${NCDUMP[@]}" -h ${FILE} | grep 'runoff_g')" != "" ]
  then
    DEPTH=$("${NCDUMP[@]}" -h ${FILE} | grep time\,\ depth | grep runoff_g | cut -d, -f 2) ; DEPTH=$(echo ${DEPTH##*( )})
    "${NCWA[@]}" -h -O --no_cell_methods -a ${DEPTH} ${FILE} tmp${EXPID}${YYYY}${MM}${COUNT}.nc
    "${NCKS[@]}" -h -O -x -v ${DEPTH},${DEPTH}_bnds tmp${EXPID}${YYYY}${MM}${COUNT}.nc ${FILE}
    rm tmp${EXPID}${YYYY}${MM}${COUNT}.nc
  fi

#----------------------------------------------------------------------------------------
#... call program for the main corrections regarding CF-netCDF
  "${CORRECT_CF[@]}" ${INC} ${OUTPUT_MAPPING_FILE} ${FILE} ${OPER}
#----------------------------------------------------------------------------------------

  if [ "$("${NCDUMP[@]}" -h ${FILE} | grep 'height_2m = 1')" != "" ]
  then
    "${NCWA[@]}" -h -O --no_cell_methods -a height_2m ${FILE} tmp${EXPID}${YYYY}${MM}${COUNT}.nc
    "${NCAP2[@]}" -h -O -s 'height_2m=float(height_2m)' tmp${EXPID}${YYYY}${MM}${COUNT}.nc ${FILE}
    rm tmp${EXPID}${YYYY}${MM}${COUNT}.nc
  fi
  if [ "$("${NCDUMP[@]}" -h ${FILE} | grep 'height_10m = 1')" != "" ]
  then
    "${NCWA[@]}" -h -O --no_cell_methods -a height_10m ${FILE} tmp${EXPID}${YYYY}${MM}${COUNT}.nc
    "${NCAP2[@]}" -h -O -s 'height_10m=float(height_10m)' tmp${EXPID}${YYYY}${MM}${COUNT}.nc ${FILE}
    rm tmp${EXPID}${YYYY}${MM}${COUNT}.nc
  fi

#... Set global attributes. Attribute param ist only a number which may be deleted
  "${NCATTED[@]}" -h -a institution,,d,, -a param,,d,, ${FILE}
  "${NCATTED[@]}" -h -a title,GLOBAL,o,c,"${GA_TITLE}" ${FILE}
  "${NCATTED[@]}" -h -a institution,GLOBAL,o,c,"${GA_INSTITUTION}" ${FILE}
  "${NCATTED[@]}" -h -a project_id,GLOBAL,o,c,"${GA_PROJECT_ID}" ${FILE}
  "${NCATTED[@]}" -h -a experiment_id,GLOBAL,o,c,"${EXPID}" ${FILE}
  "${NCATTED[@]}" -h -a realization,GLOBAL,o,c,"${GA_REALIZATION}" ${FILE}
  "${NCATTED[@]}" -h -a Conventions,GLOBAL,o,c,"${GA_CONVENTIONS}" ${FILE}
  "${NCATTED[@]}" -h -a ConventionsURL,GLOBAL,o,c,"${GA_CONVENTIONSURL}" ${FILE}
  "${NCATTED[@]}" -h -a contact,GLOBAL,o,c,"${GA_CONTACT}" ${FILE}
  "${NCATTED[@]}" -h -a icon-clm_version,GLOBAL,o,c,"${GA_ICON_CLM_VERSION}" ${FILE}
  "${NCATTED[@]}" -h -a references,GLOBAL,o,c,"${GA_REFERENCES}" ${FILE}
  "${NCATTED[@]}" -h -a creation_date,GLOBAL,o,c,"$(date '+%Y-%m-%d %H:%M:%S %Z')" ${FILE}

}

################################################################################
# Purpose: Corrects the time coordinate according to CF cell_methods metadata.
#
#          For time-aggregated variables (non-point data), the time coordinate is
#          replaced by the midpoint of the corresponding time_bnds interval.
#
#          For instantaneous variables (time: point), time_bnds and the
#          corresponding bounds attribute are removed.
#
# Old comment:
#          In case cell_methods exists the value of the time variable is replaced
#          by the value of middle of the time interval

# Arguments:
#   $1 : CELL_FILE    -> NetCDF file to process
#   $2 : CELL_PARAM   -> variable name
#   $3 : CELL_SUFFIX  -> variable suffix
#
# Temporary files:
#   - tmp${EXPID}${YYYY}${MM}${CELL_PARAM}${CELL_SUFFIX}.nc
#   - tmp${EXPID}${YYYY}${MM}${CELL_PARAM}${CELL_SUFFIX}2.nc
################################################################################
function cell_methods_time {
  CELL_FILE=$1
  CELL_PARAM=$2
  CELL_SUFFIX=$3

  local TMP1="tmp${EXPID}${YYYY}${MM}${CELL_PARAM}${CELL_SUFFIX}.nc"
  local TMP2="tmp${EXPID}${YYYY}${MM}${CELL_PARAM}${CELL_SUFFIX}2.nc"
  local ATTVAL

  ATTVAL=$("${CFU[@]}" get_attval "${CELL_FILE}" "${CELL_PARAM}${CELL_SUFFIX}" cell_methods)

  if [[ "$(echo "${ATTVAL}" | grep 'time: point')" == "" ]] && [[ "${ATTVAL}" != "--" ]]; then
    "${NCWA[@]}" -h -O -C -v time_bnds -a bnds "${CELL_FILE}" "${TMP1}"
    "${NCAP2[@]}" -O -s "time=time_bnds" "${TMP1}" "${TMP2}"
    "${NCKS[@]}" -O -v time "${TMP2}" "${TMP1}"
    "${NCATTED[@]}" -h -a ,time,d,,, "${TMP1}"
    "${NCKS[@]}" -h -A "${TMP1}" "${CELL_FILE}"
    rm -f "${TMP1}" "${TMP2}"

    if [ "${CURRENT_DATE}" -eq "${YDATE_START}" ]; then
      "${NCKS[@]}" -h -O -d time,1, "${CELL_FILE}" "${TMP1}"
      mv "${TMP1}" "${CELL_FILE}"
    fi
    rm -f "${TMP1}"

  else
    # -- Otherwise, i.e. for intantaneous values, time_bnds are deleted:
    "${NCATTED[@]}" -h -a bounds,time,d,, "${CELL_FILE}"
    "${NCKS[@]}" -h -x -v time_bnds "${CELL_FILE}" "${TMP1}"
    mv "${TMP1}" "${CELL_FILE}"
  fi
  CELL_FILE=
  CELL_PARAM=
  CELL_SUFFIX=

}

#===============================================================================
# Purpose: Performs height interpolation of ICON output fields using CDO gh2hlx,
#          restores missing-value metadata, removes temporary CDO-generated
#          height coordinates, renames height_2 -> height, converts the height
#          coordinate to float, and writes the corrected output file.
#
# Arguments:
#   $1 : COUNT     -> unique process index for temporary file names
#   $2 : HLEVS     -> array reference containing target height levels
#   $3 : OUTPATH   -> output directory for interpolated file
#   $4 : FILE      -> input NetCDF file
#
# Input:
#   - ICON NetCDF output file
#   - z_mc-topography_c.nc topography reference file
#
# Output:
#   - Height-interpolated NetCDF file with suffix z.nc
#
# Temporary files:
#   - tmp${EXPID}${YYYY}${MM}1_${COUNT}.nc
#   - tmp${EXPID}${YYYY}${MM}2_${COUNT}.nc
#===============================================================================
function height_interpolation {
  COUNT=$1
  declare -p HLEVS=("${!2}") > /dev/null
  #declare -p PARAMS=("${!3}") > /dev/null
  OUTPATH=$3
  FILE=$4

  local TMP1="tmp${EXPID}${YYYY}${MM}1_${COUNT}.nc"
  local TMP2="tmp${EXPID}${YYYY}${MM}2_${COUNT}.nc"
  local FILEOUT="${OUTPATH}/$(basename "${FILE}" .nc)z.nc"

  cp "${FILE}" "${TMP1}"

  "${NCKS[@]}" -h -A "${WORKDIR}/${EXPID}/post/z_mc-topography_c.nc" "${TMP1}"

  # -- The attributes for missing values must be deleted, because CDO does not
  #    interpolate fields that contain missing values.
  #    lmask_boundary=.true. gives -9.99e-08 as missing value in the lateral boundary zone
  "${NCATTED[@]}" -h -a _FillValue,,d,,, -a missing_value,,d,,, "${TMP1}"
  "${CDO[@]}" -s gh2hlx,$(echo ${HLEVS[@]} | sed 's/ /,/g') "${TMP1}" "${TMP2}"

  # -- CDO produces nan in the lateral boundary zone where the values are all -9.99e-08
  #    the following ncatted for re-installing the missing value has to be called twice,
  #    because a direct definition of the missing value does not work, when the
  #    missing values are nan.
  "${NCATTED[@]}" -h \
    -a _FillValue,,o,f,nan \
    -a missing_value,,o,f,nan \
    "${TMP2}"

  "${NCATTED[@]}" -h \
    -a _FillValue,,m,f,-9.99e-08 \
    -a missing_value,,m,f,-9.99e-08 \
    "${TMP2}"

  "${NCATTED[@]}" -h \
    -a _FillValue,time,d,,, \
    -a missing_value,time,d,,, \
    "${TMP2}"

  "${NCATTED[@]}" -h \
    -a _FillValue,clat_bnds,d,,, \
    -a missing_value,clat_bnds,d,,, \
    -a _FillValue,clon_bnds,d,,, \
    -a missing_value,clon_bnds,d,,, \
    "${TMP2}"

  "${NCATTED[@]}" -h \
    -a _FillValue,clat,d,,, \
    -a missing_value,clat,d,,, \
    -a _FillValue,clon,d,,, \
    -a missing_value,clon,d,,, \
    "${TMP2}"

  "${NCKS[@]}" -O -C -x -v height "${TMP2}" "${TMP2}"
  "${NCRENAME[@]}" -h -d height_2,height -v height_2,height  "${TMP2}"
  "${NCATTED[@]}" -h -a _FillValue,height,d,,, -a missing_value,height,d,,, "${TMP2}"
  "${NCAP2[@]}" -h -O -s 'height=float(height)' "${TMP2}" "${FILEOUT}"
  rm "${TMP1}" "${TMP2}"
}

#########################################################
#... function for remapping time series from ICON to rotated grid
#########################################################

function remap2rot {

  REMAP=$1    # remapnn, remapdis, remapcon, remapycon remaplaf
  PARAM=$2  # name of variable to be remapped
  SUFFIX=$3

    #... currently the weights for remap produce an error when applied. Therefore they
    #...    are not yet used in the function remap2rot until the reason is found

  echo ${REMAP} ${PARAM}${SUFFIX}
  FILE=${OUTDIR}/${YYYY_MM}/${PARAM}${SUFFIX}_ts.nc

  #... preparation for coordinate corrections at the end of this function
  #if [ "$("${NCDUMP[@]}" -h ${FILE} | grep 'height_2m')" != "" ] --> too broad and read also history
  if "${NCDUMP[@]}" -h "${FILE}" | grep -qE '^[[:space:]]*(float|double)[[:space:]]+height_2m[[:space:]]*(\(|;)'
  then
    #COORDINATES=$("${NCDUMP[@]}" -h "${FILE}" | grep "${PARAM}:coordinates" | cut -d'"' -f2 | sed 's!clon\ clat!lon\ lat!')
    COORDINATES=$(
      "${NCDUMP[@]}" -h "${FILE}" \
      | grep "${PARAM}:coordinates" \
      | cut -d'"' -f2 \
      | sed -e 's!clat clon!lat lon!' -e 's!clon clat!lat lon!'
    )
    "${NCKS[@]}" -h -O -v height_2m "${FILE}" tmp${EXPID}${YYYY}${MM}${PARAM}${SUFFIX}00.nc
    "${NCATTED[@]}" -h -a ,global,d,, tmp${EXPID}${YYYY}${MM}${PARAM}${SUFFIX}00.nc
  fi

  #if [ "$("${NCDUMP[@]}" -h ${FILE} | grep 'height_10m')" != "" ] --> too broad and read also history
  if "${NCDUMP[@]}" -h "${FILE}" | grep -qE '^[[:space:]]*(float|double)[[:space:]]+height_10m[[:space:]]*(\(|;)'
  then
    #COORDINATES=$("${NCDUMP[@]}" -h "${FILE}" | grep "${PARAM}:coordinates" | cut -d'"' -f2 | sed 's!clon\ clat!lon\ lat!')
    COORDINATES=$(
      "${NCDUMP[@]}" -h "${FILE}" \
      | grep "${PARAM}:coordinates" \
      | cut -d'"' -f2 \
      | sed -e 's!clat clon!lat lon!' -e 's!clon clat!lat lon!'
    )
    "${NCKS[@]}" -h -O -v height_10m "${FILE}" tmp${EXPID}${YYYY}${MM}${PARAM}${SUFFIX}00.nc
    "${NCATTED[@]}" -h -a ,global,d,, tmp${EXPID}${YYYY}${MM}${PARAM}${SUFFIX}00.nc
  fi

  #... add clon/clat and clon_bnds/clat_bnds and coordinates attribute (needed for remapping with CDO)
  if [ "$("${CFU[@]}" get_attval ${FILE} ${PARAM}${SUFFIX} coordinates)" == "--" ]
  then
    "${NCKS[@]}" -h -A ${OUTDIR}/icon_grid.nc ${FILE}
    "${NCATTED[@]}" -h -a coordinates,${PARAM},c,c,"clon clat" ${FILE}
  fi

  #... change missing_value to standard -1.E20
  fillvalue=$("${NCDUMP[@]}" -h ${FILE} | grep ${PARAM}:_FillValue)
  if [ "${fillvalue}" ]
  then
    "${CDO[@]}" -s setmissval,-1.E20 ${FILE} ${FILE}_tmp${EXPID}${YYYY}${MM}
    mv ${FILE}_tmp${EXPID}${YYYY}${MM} ${FILE}
  fi

  if [ y${SUFFIX: -1} == 'yz' ]
  then
    # data interpolated to heights over terrain have other weights
    "${CDO[@]}" -s -P ${OMP_THREADS_POST} ${REMAP},${TARGET_GRID} ${FILE} tmp${EXPID}${YYYY}${MM}${PARAM}${SUFFIX}.nc
  else
    #weights with source mask
    "${CDO[@]}" -s -P ${OMP_THREADS_POST} remap,${TARGET_GRID},${OUTDIR}/${REMAP}_weights.nc ${FILE} tmp${EXPID}${YYYY}${MM}${PARAM}${SUFFIX}.nc
  fi
  mv tmp${EXPID}${YYYY}${MM}${PARAM}${SUFFIX}.nc ${FILE}

  #"${NCKS[@]}" -h -O -v ${PARAM} ${FILE} tmp${EXPID}${YYYY}${MM}${PARAM}${SUFFIX}1.nc
  #mv tmp${EXPID}${YYYY}${MM}${PARAM}${SUFFIX}1.nc ${FILE}
  # Keep remapped variable together with rotated-grid metadata
  KEEP_VARS="${PARAM}"

  if "${NCDUMP[@]}" -h "${FILE}" | grep -qE '^[[:space:]]*(float|double)[[:space:]]+lon[[:space:]]*(\(|;)' ; then
    KEEP_VARS="${KEEP_VARS},lon"
  fi

  if "${NCDUMP[@]}" -h "${FILE}" | grep -qE '^[[:space:]]*(float|double)[[:space:]]+lat[[:space:]]*(\(|;)' ; then
    KEEP_VARS="${KEEP_VARS},lat"
  fi

  if "${NCDUMP[@]}" -h "${FILE}" | grep -qE '^[[:space:]]*(char|byte|short|int|int64|float|double)[[:space:]]+rotated_pole[[:space:]]*(\(|;)' ; then
    KEEP_VARS="${KEEP_VARS},rotated_pole"
  fi

  "${NCKS[@]}" -h -O -v "${KEEP_VARS}" "${FILE}" tmp${EXPID}${YYYY}${MM}${PARAM}${SUFFIX}1.nc
  mv tmp${EXPID}${YYYY}${MM}${PARAM}${SUFFIX}1.nc "${FILE}"

  #... correct the coordinates attribute
  if [ -f tmp${EXPID}${YYYY}${MM}${PARAM}${SUFFIX}00.nc ]
  then
    "${NCKS[@]}" -h -A  tmp${EXPID}${YYYY}${MM}${PARAM}${SUFFIX}00.nc ${FILE}
    "${NCATTED[@]}" -h -a coordinates,${PARAM},o,c,"${COORDINATES}" ${FILE}
    rm tmp${EXPID}${YYYY}${MM}${PARAM}${SUFFIX}00.nc
  fi

  #... in case cell_methods exists the value of the time variable is replaced by the value of middle of the time interval
  cell_methods_time ${OUTDIR}/${YYYY_MM}/${PARAM}${SUFFIX}_ts.nc ${PARAM} ${SUFFIX}

  #... modify dimension and cell_methods attribute for soil water
  if [ "$("${NCDUMP[@]}" -h ${FILE} | grep 'lwe_thickness_of_moisture_content_of_soil_layer')" != "" ] || \
     [ "$("${NCDUMP[@]}" -h ${FILE} | grep 'lwe_thickness_of_frozen_water_content_of_soil_layer')" != "" ]
  then
    DEPTH=$("${NCDUMP[@]}" -h ${FILE} | grep time\,\ depth | cut -d, -f 2) ; DEPTH=$(echo ${DEPTH##*( )})
    "${NCKS[@]}" -3 ${FILE} tmp${EXPID}${YYYY}${MM}${PARAM}${SUFFIX}soil.nc
    if [ ${DEPTH} != "depth" ]
    then
      "${NCRENAME[@]}" -d ${DEPTH},depth  \
                             -v ${DEPTH},depth -v ${DEPTH}_bnds,depth_bnds tmp${EXPID}${YYYY}${MM}${PARAM}${SUFFIX}soil.nc
    fi
    "${NCKS[@]}" -O -4 tmp${EXPID}${YYYY}${MM}${PARAM}${SUFFIX}soil.nc ${FILE}
    "${NCATTED[@]}" -h -a cell_methods,${PARAM},o,c,"time: point depth: sum" ${FILE}
    "${NCATTED[@]}" -h -a bounds,depth,o,c,"depth_bnds" ${FILE}
    rm tmp${EXPID}${YYYY}${MM}${PARAM}${SUFFIX}soil.nc
  fi

  #... modify dimension and cell_methods attribute for soil temperature. Remove 1 dimension, this is the same as T_S
  if [ "$("${NCDUMP[@]}" -h ${FILE} | grep 'solid_earth_subsurface_temperature')" != "" ]
  then
    DEPTH=$("${NCDUMP[@]}" -h ${FILE} | grep time\,\ depth | cut -d, -f 2) ; DEPTH=$(echo ${DEPTH##*( )})
    "${NCKS[@]}" -3 ${FILE} tmp${EXPID}${YYYY}${MM}${PARAM}${SUFFIX}soil.nc
    if [ ${DEPTH} != "depth" ]
    then
      "${NCRENAME[@]}" -d ${DEPTH},depth  \
                             -v ${DEPTH},depth tmp${EXPID}${YYYY}${MM}${PARAM}${SUFFIX}soil.nc
    fi
    #... remove first dimension
    "${NCKS[@]}" -O -4 -d depth,1, tmp${EXPID}${YYYY}${MM}${PARAM}${SUFFIX}soil.nc ${FILE}
    "${NCATTED[@]}" -h -a cell_methods,${PARAM},o,c,"time: point" ${FILE}
    rm tmp${EXPID}${YYYY}${MM}${PARAM}${SUFFIX}soil.nc
  fi

  #... modify short_name and long_name of parameter depth
  if [ "$("${NCDUMP[@]}" -h ${FILE} | grep 'double depth')" != "" ]
  then
    "${NCATTED[@]}" -h -a short_name,depth,o,c,"depth" ${FILE}
    "${NCATTED[@]}" -h -a long_name,depth,o,c,"depth below land" ${FILE}
  fi

  #... CDO writes institution=MPIMET into the output of each variable, this will be deleted here
  "${NCATTED[@]}" -h -a institution,,d,, ${FILE}

}

##################################################################################################################
##################################################################################################################
#... functions for building time series
#      these are the essential functions to create the *_ts.nc files on post/YYYY_MM
#      the input quantities of for these functions are the icon_YYYYMMDDTHHmmssZ output files from ICON
##################################################################################################################
##################################################################################################################

#... building a time series for a given quantity
function timeseries {
  PARAM=$1
  OUTNN=$2
  REMAP=$3 # remapnn, remapdis, remapcon, remapycon remaplaf
#  WEIGHTS_FILE=$3
#  LSO=$4

  # if the 2nd argument is not given it is assumed to be an additional quantity and the function timeseriesa is called
  if [ -z $2 ]
  then
    timeseriesa $1
    return
  fi

  cd ${INPDIR}/${YYYY_MM}/${OUTNN}
  rm -f tmp${EXPID}${YYYY}${MM}${PARAM}.nc
  "${NCRCAT[@]}" --no_cell_methods -h -O -v ${PARAM} icon_*[!cpz].nc ${OUTDIR}/${YYYY_MM}/${PARAM}_ts.nc

  remap2rot ${REMAP} ${PARAM}

}

##################################################################################################################
# building a time series on pressure levels for a given quantity

function timeseriesp {
  PARAM=$1
  OUTNN=$2
  declare -p PLEVS=("${!3}") > /dev/null
  REMAP=$4 # remapnn, remapdis, remapcon, remapycon remaplaf

  # if the 4th argument is not given it is assumed to be an additional quantity and the function timeseriesap is called
  if [ -z $4 ]
  then
    timeseriesap $1 $2
    return
  fi

  NPLEV=0
  while [[ ${NPLEV} -lt ${#PLEVS[@]} ]]
  do
    PASCAL=$("${PYTHON[@]}" -c "print(${PLEVS[${NPLEV}]} * 100.)")
#    PASCAL=$("${PYTHON[@]}" -c "print(${PLEVS[${NPLEV}]})")
    PLEV=$("${PYTHON[@]}" -c "print(int(${PLEVS[${NPLEV}]}))")
    cd ${INPDIR}/${YYYY_MM}/${OUTNN}
    rm -f tmp${EXPID}${YYYY}${MM}${PARAM}${PLEV}p.nc
    "${NCRCAT[@]}" --no_cell_methods -h -O -d pressure,${PASCAL},${PASCAL} -v ${PARAM} icon_*p.nc* ${OUTDIR}/${YYYY_MM}/${PARAM}${PLEV}p_ts.nc

    "${NCWA[@]}" -h -O --no_cell_methods -a pressure -v ${PARAM} ${OUTDIR}/${YYYY_MM}/${PARAM}${PLEV}p_ts.nc tmp${EXPID}${YYYY}${MM}${PARAM}${PLEV}p.nc
    cp tmp${EXPID}${YYYY}${MM}${PARAM}${PLEV}p.nc ${OUTDIR}/${YYYY_MM}/${PARAM}${PLEV}p_ts.nc
    rm -f tmp${EXPID}${YYYY}${MM}${PARAM}${PLEV}p.nc
    "${NCKS[@]}" -h -O -v pressure  ${OUTDIR}/${YYYY_MM}/${PARAM}${PLEV}p_ts.nc tmp${EXPID}${YYYY}${MM}${PARAM}${PLEV}pressure.nc
    "${NCATTED[@]}"  -h -a ,global,d,, tmp${EXPID}${YYYY}${MM}${PARAM}${PLEV}pressure.nc
    remap2rot ${REMAP} ${PARAM} ${PLEV}p
    "${NCKS[@]}" -h -A tmp${EXPID}${YYYY}${MM}${PARAM}${PLEV}pressure.nc ${OUTDIR}/${YYYY_MM}/${PARAM}${PLEV}p_ts.nc
    rm tmp${EXPID}${YYYY}${MM}${PARAM}${PLEV}pressure.nc
    "${NCATTED[@]}" -h -O -a coordinates,$1,o,c,'lon lat pressure' ${OUTDIR}/${YYYY_MM}/${PARAM}${PLEV}p_ts.nc
    let "NPLEV = NPLEV + 1"
  done
}

##################################################################################################################
#... building a time series on height levels for a given quantity

function timeseriesz {
  PARAM=$1
  OUTNN=$2
  declare -p ZLEVS=("${!3}") > /dev/null
  REMAP=$4 # remapnn, remapdis, remapcon, remapycon remaplaf

  # if the 4th argument is not given it is assumed to be an additional quantity and the function timeseriesaz is called
  if [ -z $4 ]
  then
    timeseriesaz $1 $2
    return
  fi

  set +e
  "${NCDUMP[@]}" -h ${INPDIR}/${YYYY_MM}/${OUTNN}/icon_${ISO_NEXT_DATE}z.nc | grep float\ ${PARAM} | grep height > /dev/null 2>&1
  ERROR_STATUS=$?
  set -e
  if [ ${ERROR_STATUS}  -eq 0 ]
  then
    HEIGHT=height
    NN=
  else
    HEIGHT=altitude
    NN=NN
  fi
  NZLEV=0
  while [[ ${NZLEV} -lt ${#ZLEVS[@]} ]]
  do
    ZLEV=$("${PYTHON[@]}" -c "print(int(${ZLEVS[${NZLEV}]}))")
    cd ${INPDIR}/${YYYY_MM}/$2
    "${NCRCAT[@]}" --no_cell_methods -h -O -d ${HEIGHT},${ZLEV}.,${ZLEV}. -v ${PARAM} icon_*z.nc* ${OUTDIR}/${YYYY_MM}/${PARAM}${ZLEV}z${NN}_ts.nc

    "${NCWA[@]}" -h -O --no_cell_methods -a ${HEIGHT} -v ${PARAM} ${OUTDIR}/${YYYY_MM}/${PARAM}${ZLEV}z${NN}_ts.nc tmp${EXPID}${YYYY}${MM}${PARAM}${ZLEV}z${NN}.nc
    cp tmp${EXPID}${YYYY}${MM}${PARAM}${ZLEV}z${NN}.nc ${OUTDIR}/${YYYY_MM}/${PARAM}${ZLEV}z${NN}_ts.nc
    rm tmp${EXPID}${YYYY}${MM}${PARAM}${ZLEV}z${NN}.nc
    "${NCKS[@]}" -h -O -v ${HEIGHT}  ${OUTDIR}/${YYYY_MM}/${PARAM}${ZLEV}z${NN}_ts.nc tmp${EXPID}${YYYY}${MM}${PARAM}${ZLEV}${HEIGHT}.nc
    "${NCATTED[@]}"  -h -a ,global,d,, tmp${EXPID}${YYYY}${MM}${PARAM}${ZLEV}${HEIGHT}.nc
    remap2rot ${REMAP} ${PARAM} ${ZLEV}z${NN}
    "${NCKS[@]}" -h -A tmp${EXPID}${YYYY}${MM}${PARAM}${ZLEV}${HEIGHT}.nc ${OUTDIR}/${YYYY_MM}/${PARAM}${ZLEV}z${NN}_ts.nc
    rm tmp${EXPID}${YYYY}${MM}${PARAM}${ZLEV}${HEIGHT}.nc
    "${NCATTED[@]}" -h -O -a coordinates,$1,o,c,"lon lat ${HEIGHT}" ${OUTDIR}/${YYYY_MM}/${PARAM}${ZLEV}z${NN}_ts.nc
    let "NZLEV = NZLEV + 1"
  done
}

##################################################################################################################
##################################################################################################################
#... functions for calculating additional quantities
#      the calculations use *_ts.nc files from post/YYYY_MM
##################################################################################################################
##################################################################################################################

function timeseriesa {

  case ${1} in

    'ASOD_S')
      # averaged total downward sw radiation at the surface
      echo calculate ASOD_S ...
      infile1=${OUTDIR}/${YYYY_MM}/ASOB_S_ts.nc
      infile2=${OUTDIR}/${YYYY_MM}/ASODIFU_S_ts.nc
      outfile=${OUTDIR}/${YYYY_MM}/ASOD_S_ts.nc
      if [ ! -e ${outfile} ] ; then
        if [ -f ${infile1} -a -f ${infile2} ] ; then
          cp  ${infile1} tmp${EXPID}${YYYY}${MM}ASOD_S.nc
          "${NCKS[@]}" -h -A -v ASODIFU_S ${infile2} tmp${EXPID}${YYYY}${MM}ASOD_S.nc
          "${NCAP2[@]}" -O -s "ASOD_S=ASOB_S+ASODIFU_S" tmp${EXPID}${YYYY}${MM}ASOD_S.nc tmp${EXPID}${YYYY}${MM}ASOD_S.nc
          "${NCKS[@]}" -h -O -v ASOD_S,lat,lon,rotated_pole tmp${EXPID}${YYYY}${MM}ASOD_S.nc ${outfile}
          "${NCATTED[@]}" -h -a long_name,ASOD_S,m,c,"averaged total downward sw radiation at the surface" -a standard_name,ASOD_S,o,c,"surface_downwelling_shortwave_flux_in_air" ${outfile}
          rm tmp${EXPID}${YYYY}${MM}ASOD_S.nc
        else
          echo "Input fields " ASOB_S " and/or " ASODIFU_S " for calculating " ASOD_S " are missing"
        fi
      fi
      ;;

    'ASODIRD_S')
      # averaged solar direct downward flux at the surface
      echo calculate ASODIRD_S ...
      infile1=${OUTDIR}/${YYYY_MM}/ASOB_S_ts.nc
      infile2=${OUTDIR}/${YYYY_MM}/ASODIFU_S_ts.nc
      infile3=${OUTDIR}/${YYYY_MM}/ASODIFD_S_ts.nc
      outfile=${OUTDIR}/${YYYY_MM}/ASODIRD_S_ts.nc

      if [[ -f ${infile1} ]] && [[ -f ${infile2} ]] && [[ -f ${infile3} ]] ; then
        "${CDO[@]}" -s add ${infile1} -sub ${infile2} ${infile3} ${outfile}
        "${NCRENAME[@]}" -h -v ASOB_S,ASODIRD_S ${outfile}
        "${NCATTED[@]}" -h -a standard_name,ASODIRD_S,m,c,"surface_direct_downwelling_shortwave_flux_in_air" ${outfile}
        "${NCATTED[@]}" -h -a long_name,ASODIRD_S,m,c,"averaged surface downward direct solar radiation" ${outfile}
        "${NCATTED[@]}" -h -a cell_methods,ASODIRD_S,m,c,"time: mean" ${outfile}

        # -- CDO removes the time_bnds units, create it again with the following command
        "${NCATTED[@]}" -h -a units,time_bnds,o,c,"$("${CFU[@]}" get_attval ${OUTDIR}/${YYYY_MM}/ASOB_S_ts.nc time units)" ${outfile}
      else
        echo "Input fields ASOB_S and/or ASODIFU_S and/or ASODIFD_S for calculating solar direct downward flux at the surface ASODIRD_S are missing"
      fi
      ;;

    'ASOU_T')
      # averaged solar upward radiation at top
      echo calculate ASOU_T ...
      infile1=${OUTDIR}/${YYYY_MM}/ASOD_T_ts.nc
      infile2=${OUTDIR}/${YYYY_MM}/ASOB_T_ts.nc
      outfile=${OUTDIR}/${YYYY_MM}/ASOU_T_ts.nc
      if [ ! -e ${outfile} ] ; then
        if [ -f ${infile1} -a -f ${infile2} ] ; then
          cp  ${infile1} tmp${EXPID}${YYYY}${MM}ASOU_T.nc
          "${NCKS[@]}" -h -A -v ASOB_T ${infile2} tmp${EXPID}${YYYY}${MM}ASOU_T.nc
          "${NCAP2[@]}" -O -s "ASOU_T=ASOD_T-ASOB_T" tmp${EXPID}${YYYY}${MM}ASOU_T.nc tmp${EXPID}${YYYY}${MM}ASOU_T.nc
          "${NCKS[@]}" -h -O -v ASOU_T,lat,lon,rotated_pole tmp${EXPID}${YYYY}${MM}ASOU_T.nc ${outfile}
          "${NCATTED[@]}" -h -a long_name,ASOU_T,m,c,"averaged solar upward radiation at top" -a standard_name,ASOU_T,m,c,"toa_outgoing_shortwave_flux" ${outfile}
          rm tmp${EXPID}${YYYY}${MM}ASOU_T.nc
        else
          echo "Input fields " ASOD_T " and/or " ASOB_T " for calculating " ASOU_T " are missing"
        fi
      fi
      ;;

    'ATHD_S')
      # averaged total downward lw radiation at the surface
      echo calculate ATHD_S ...
      infile1=${OUTDIR}/${YYYY_MM}/ATHB_S_ts.nc
      infile2=${OUTDIR}/${YYYY_MM}/ATHU_S_ts.nc
      outfile=${OUTDIR}/${YYYY_MM}/ATHD_S_ts.nc
      if [ ! -e ${outfile} ] ; then
        if [ -f ${infile1} -a -f ${infile2} ] ; then
          cp  ${infile1} tmp${EXPID}${YYYY}${MM}ATHD_S.nc
          "${NCKS[@]}" -h -A -v ATHU_S ${infile2} tmp${EXPID}${YYYY}${MM}ATHD_S.nc
          "${NCAP2[@]}" -O -s "ATHD_S=ATHB_S+ATHU_S" tmp${EXPID}${YYYY}${MM}ATHD_S.nc tmp${EXPID}${YYYY}${MM}ATHD_S.nc
          "${NCKS[@]}" -h -O -v ATHD_S,lat,lon,rotated_pole tmp${EXPID}${YYYY}${MM}ATHD_S.nc ${outfile}
          "${NCATTED[@]}" -h -a long_name,ATHD_S,m,c,"averaged total downward lw radiation at the surface" -a standard_name,ATHD_S,o,c,"surface_downwelling_longwave_flux_in_air" ${outfile}
          rm tmp${EXPID}${YYYY}${MM}ATHD_S.nc
        else
          echo "Input fields " ATHB_S " and/or " ATHU_S " for calculating " ATHD_S " are missing"
        fi
      fi
      ;;

   'DD_10M')
      #  wind direction in 10m height
      echo calculate DD_10M ...
      varname=DD_10M
      varnameULON=U_10M
      varnameVLAT=V_10M
      uvlonlatfile=UVlonlat_10M_ts.nc
      outfile=${OUTDIR}/${YYYY_MM}/${varname}_ts.nc
      infile1=${OUTDIR}/${YYYY_MM}/${varnameULON}_ts.nc
      infile2=${OUTDIR}/${YYYY_MM}/${varnameVLAT}_ts.nc
      if [ ! -e ${outfile} ] ; then
        if [ -f ${infile1} -a -f ${infile2} ] ; then
          cp ${infile1} ${uvlonlatfile}
          "${NCKS[@]}" -h -A -v ${varnameVLAT} ${infile2} ${uvlonlatfile}
        else
          echo "Input fields for calculating wind direction at 10m height are missing"
        fi
        "${NCAP2[@]}" -O -s "${varname}=float(45.0/atan(1.0)*atan2(${varnameULON},${varnameVLAT})+180.0)" ${uvlonlatfile} ${uvlonlatfile}
        "${NCKS[@]}" -h -O -v ${varname},lat,lon,rotated_pole,height_10m ${uvlonlatfile} ${outfile}
        "${NCATTED[@]}" -h -O -a standard_name,${varname},o,c,'wind_from_direction' -a long_name,${varname},o,c,'wind direction at 10m height' -a units,${varname},o,c,'deg' -a coordinates,${varname},c,c,'lon lat height_10m' -a cell_methods,${varname},o,c,'time: point' ${outfile}
        rm ${uvlonlatfile}
        # "The wind direction at 10m height was determined w.r.t. the geographical WGS84 system."
      fi
      ;;

   'DTR_2M')
      #  echo diurnal temperature range
      echo calculate DTR_2M ...
      outfile=${OUTDIR}/${YYYY_MM}/DTR_2M_ts.nc
      infile1=${OUTDIR}/${YYYY_MM}/TMAX_2M_ts.nc
      infile2=${OUTDIR}/${YYYY_MM}/TMIN_2M_ts.nc
      if [ ! -e ${outfile} ] ; then
        if [ -f ${infile1} -a -f ${infile2} ]
        then
          "${CDO[@]}" -s sub ${infile1} ${infile2} ${outfile}
          "${NCRENAME[@]}" -h -v TMAX_2M,DTR_2M ${outfile}
          "${NCATTED[@]}" -h -a long_name,DTR_2M,m,c,"diurnal temperature range" ${outfile}
          "${NCATTED[@]}" -h -a cell_methods,DTR_2M,m,c,"time: range" ${outfile}
          "${NCATTED[@]}" -h -a units,time_bnds,o,c,"$("${CFU[@]}" get_attval ${infile2} time units)" ${outfile}
        else
          echo "Input fields TMAX_2M and/or TMIN_2M for the diurnal temperature range DTR are missing"
        fi
      fi
      ;;

   'FIELDCAP')
      # field capacity, pore volume and wilting point
      echo calculate FIELDCAP, PORVOL, WILPOINT ...
      capfield=('1.E-10' '1.E-10' '0.196' '0.260' '0.340' '0.370' '0.463' '0.763' '-1.E20' '-1.E20')
      porfield=('1.E-10' '1.E-10' '0.364' '0.445' '0.455' '0.475' '0.507' '0.863' '-1.E20' '-1.E20')
      wilfield=('0.0' '0.0' '0.042' '0.100' '0.110' '0.185' '0.257' '0.265' '-1.E20' '-1.E20')

      iofile=${OUTDIR}/icon_c.nc

      if [ -f ${iofile} ] ; then
        "${NCKS[@]}" -O -v SOILTYP ${OUTDIR}/icon_c.nc ${OUTDIR}/SOILTYP_c.nc
        cp ${OUTDIR}/SOILTYP_c.nc ${OUTDIR}/SOILTYP_p.nc
        cp ${OUTDIR}/SOILTYP_c.nc ${OUTDIR}/SOILTYP_w.nc

        for i in {1..10..1}
        do
          im1=$((i-1))
          #          echo $i ${capfield[$im1]} $im1
          "${NCAP2[@]}" -O -s 'where(SOILTYP=='$i') SOILTYP='${capfield[$im1]} ${OUTDIR}/SOILTYP_c.nc ${OUTDIR}/SOILTYP_c.nc
          "${NCAP2[@]}" -O -s 'where(SOILTYP=='$i') SOILTYP='${porfield[$im1]} ${OUTDIR}/SOILTYP_p.nc ${OUTDIR}/SOILTYP_p.nc
          "${NCAP2[@]}" -O -s 'where(SOILTYP=='$i') SOILTYP='${wilfield[$im1]} ${OUTDIR}/SOILTYP_w.nc ${OUTDIR}/SOILTYP_w.nc
        done

        mv ${OUTDIR}/SOILTYP_c.nc ${OUTDIR}/FIELDCAP.nc
        mv ${OUTDIR}/SOILTYP_p.nc ${OUTDIR}/PORVOL.nc
        mv ${OUTDIR}/SOILTYP_w.nc ${OUTDIR}/WILPOINT.nc

        "${NCRENAME[@]}" -v SOILTYP,FIELDCAP ${OUTDIR}/FIELDCAP.nc
        "${NCRENAME[@]}" -v SOILTYP,PORVOL ${OUTDIR}/PORVOL.nc
        "${NCRENAME[@]}" -v SOILTYP,WILPOINT ${OUTDIR}/WILPOINT.nc

        # -- Add standard_name to files:
        "${NCATTED[@]}" -h -a standard_name,FIELDCAP,m,c,"volume_fraction_of_condensed_water_in_soil_at_field_capacity" ${OUTDIR}/FIELDCAP.nc
        "${NCATTED[@]}" -h -a standard_name,PORVOL,m,c,"volume_fraction_of_pore_volume_in_soil" ${OUTDIR}/PORVOL.nc
        "${NCATTED[@]}" -h -a standard_name,WILPOINT,m,c,"volume_fraction_of_condensed_water_at_wilting_point" ${OUTDIR}/WILPOINT.nc

        # -- Add long_name to files:
        "${NCATTED[@]}" -h -a long_name,FIELDCAP,m,c,"volume fraction of soil moisture content at field capacity" ${OUTDIR}/FIELDCAP.nc
        "${NCATTED[@]}" -h -a long_name,PORVOL,m,c,"volume fraction of soil pore volume" ${OUTDIR}/PORVOL.nc
        "${NCATTED[@]}" -h -a long_name,WILPOINT,m,c,"volume fraction of soil moisture at wilting point" ${OUTDIR}/WILPOINT.nc

        # -- Merge files into icon_c.nc
        "${NCKS[@]}" -A ${OUTDIR}/FIELDCAP.nc ${OUTDIR}/icon_c.nc
        "${NCKS[@]}" -A ${OUTDIR}/PORVOL.nc ${OUTDIR}/icon_c.nc
        "${NCKS[@]}" -A ${OUTDIR}/WILPOINT.nc ${OUTDIR}/icon_c.nc

        # -- Add extra attributes:
        rawdata=$("${NCDUMP[@]}" -h ${EXTPAR}|grep -i rawdata|cut -d \" -f2)
        "${NCATTED[@]}" -h -a rawdata,global,c,c,"${rawdata}"  ${OUTDIR}/icon_c.nc
        "${NCATTED[@]}" -h -a flag_values,SOILTYP,c,c,"1, 2, 3, 4, 5, 6, 7, 8, 9, 0" -a flag_meanings,SOILTYP,c,c,"ice rock sand sandy_loam loam clay_loam clay peat water sea_ice" ${OUTDIR}/icon_c.nc
        "${NCATTED[@]}" -h -a missing_value,SOILTYP,d,, -a missing_value,FIELDCAP,d,,  -a missing_value,PORVOL,d,, -a missing_value,WILPOINT,d,, ${OUTDIR}/icon_c.nc
        "${NCATTED[@]}" -h -a _FillValue,SOILTYP,d,, -a _FillValue,FIELDCAP,m,f,-1.E20 -a _FillValue,PORVOL,m,f,-1.E20 -a _FillValue,WILPOINT,m,f,-1.E20 ${OUTDIR}/icon_c.nc

        # -- Remove temporal files:
        rm ${OUTDIR}/FIELDCAP.nc ${OUTDIR}/PORVOL.nc ${OUTDIR}/WILPOINT.nc
      else
        echo "Input file ${iofile} is missing"
      fi
      ;;

    'FR_SNOW')
      #  snow fraction
      echo calculate FR_SNOW ...
      varnamew=W_SNOW
      varnamef=FR_SNOW
      outfile=${OUTDIR}/${YYYY_MM}/${varnamef}_ts.nc
      infile1=${OUTDIR}/${YYYY_MM}/${varnamew}_ts.nc
      if [ ! -e ${outfile} ] ; then
        if [ -f ${infile1} ] ; then
          cp  ${infile1} tmp${EXPID}${YYYY}${MM}snowfraction.nc
          "${NCAP2[@]}" -O -s "SNOW_flg = float(${varnamew} > 0.0000005); SNOW = float(${varnamew}/0.015); where(SNOW>1.0) SNOW=1.0f; where(SNOW<0.01) SNOW=0.01f; ${varnamef}=float(SNOW*SNOW_flg)" tmp${EXPID}${YYYY}${MM}snowfraction.nc tmp${EXPID}${YYYY}${MM}snowfraction.nc
          "${NCKS[@]}" -h -O -v ${varnamef},lat,lon,rotated_pole tmp${EXPID}${YYYY}${MM}snowfraction.nc ${outfile}
          "${NCATTED[@]}" -h -O -a standard_name,${varnamef},o,c,'surface_snow_area_fraction' -a long_name,${varnamef},o,c,'Snow Area Fraction' -a units,${varnamef},o,c,'1' -a cell_methods,${varnamef},o,c,'time: point'  ${outfile}
          rm   tmp${EXPID}${YYYY}${MM}snowfraction.nc
          # "The snow area fraction was calculated with the internally used method."
        else
          echo "Input field " ${varnamew} " for calculating snow area fraction is missing"
        fi
      fi
      ;;

   'T_SNOW')
      #  snow temperature
      echo "set T_SNOW to _FillValue where FR_SNOW = 0"
      varnamef=FR_SNOW
      varnamet=T_SNOW
      outfile=${OUTDIR}/${YYYY_MM}/${varnamet}_ts.nc
      infile1=${OUTDIR}/${YYYY_MM}/${varnamef}_ts.nc
      infile2=${OUTDIR}/${YYYY_MM}/${varnamet}_ts.nc
      if [[ -f ${infile1} && -f ${infile2} ]] ; then
        "${CDO[@]}" -P 8 -O --no_history merge ${infile1} ${infile2} tmp${EXPID}${YYYY}${MM}FR_T_SNOW.nc
        "${NCAP2[@]}" -O -s 'where(FR_SNOW==0)FR_SNOW=-1.E20;where(FR_SNOW>0)FR_SNOW=1;T_SNOW=FR_SNOW*T_SNOW' tmp${EXPID}${YYYY}${MM}FR_T_SNOW.nc tmp2${EXPID}${YYYY}${MM}FR_T_SNOW.nc
        "${CDO[@]}" -P 8 -O --no_history -selvar,T_SNOW tmp2${EXPID}${YYYY}${MM}FR_T_SNOW.nc ${outfile}
        rm tmp${EXPID}${YYYY}${MM}FR_T_SNOW.nc tmp2${EXPID}${YYYY}${MM}FR_T_SNOW.nc
        #echo "Snow temperature (T_SNOW) is now adjusted for regions with FR_SNOW>0"
      else
        echo "Snow temperature (T_SNOW) or snow fraction (FR_SNOW) is not available."
      fi
      ;;

   'PREC_CON')
      # convective precipitation
      echo calculate PREC_CON ...
      infile1=${OUTDIR}/${YYYY_MM}/RAIN_CON_ts.nc
      infile2=${OUTDIR}/${YYYY_MM}/SNOW_CON_ts.nc
      outfile=${OUTDIR}/${YYYY_MM}/PREC_CON_ts.nc
      if [ ! -e ${outfile} ] ; then
        if [ -f ${infile1} -a -f ${infile2} ] ; then
          cp  ${infile1} tmp${EXPID}${YYYY}${MM}PREC_CON.nc
          "${NCKS[@]}" -h -A -v SNOW_CON ${infile2} tmp${EXPID}${YYYY}${MM}PREC_CON.nc
          "${NCAP2[@]}" -O -s "PREC_CON=RAIN_CON+SNOW_CON" tmp${EXPID}${YYYY}${MM}PREC_CON.nc tmp${EXPID}${YYYY}${MM}PREC_CON.nc
          "${NCKS[@]}" -h -O -v PREC_CON,lat,lon,rotated_pole tmp${EXPID}${YYYY}${MM}PREC_CON.nc ${outfile}
          "${NCATTED[@]}" -h -a long_name,PREC_CON,m,c,"convective precipitation" -a standard_name,PREC_CON,o,c,"convective_precipitation_amount" ${outfile}
          rm tmp${EXPID}${YYYY}${MM}PREC_CON.nc
        else
          echo "Input fields " RAIN_CON " and/or " SNOW_CON " for calculating " PREC_CON " are missing"
        fi
      fi
      ;;

   'PVAP_2M')
      # water vapour partial pressure in 2m
      echo calculate PVAP_2M ...
      outfile=${OUTDIR}/${YYYY_MM}/PVAP_2M_ts.nc
      infile1=${OUTDIR}/${YYYY_MM}/APS_ts.nc
      infile2=${OUTDIR}/${YYYY_MM}/AQV_2M_ts.nc
      infile3=${OUTDIR}/${YYYY_MM}/AT_2M_ts.nc
      infile4=${OUTDIR}/${YYYY_MM}/ARELHUM_2M_ts.nc
      if [ ! -e ${outfile} ] ; then
        if [ -f ${infile1} -a -f ${infile2} ] ; then
          cp ${infile1} ${OUTDIR}/${YYYY_MM}/PS_QV_ts.nc
          "${NCKS[@]}" -A ${infile2} ${OUTDIR}/${YYYY_MM}/PS_QV_ts.nc
          "${NCAP2[@]}" -O -s "PVAP_2M=float(1/(0.622+0.378*AQV_2M)*AQV_2M*APS)" ${OUTDIR}/${YYYY_MM}/PS_QV_ts.nc ${OUTDIR}/${YYYY_MM}/PVAP_2M_ts_tmp.nc
          "${NCKS[@]}" -h -O -v PVAP_2M,lon,lat,rotated_pole ${OUTDIR}/${YYYY_MM}/PVAP_2M_ts_tmp.nc ${outfile}
          "${NCATTED[@]}" -h -a standard_name,PVAP_2M,m,c,"water_vapour_partial_pressure_in_air" ${outfile}
          "${NCATTED[@]}" -h -a units,PVAP_2M,m,c,"Pa" ${outfile}
          "${NCATTED[@]}" -h -a long_name,PVAP_2M,m,c,"water vapour partial pressure in 2m" ${outfile}
          "${NCATTED[@]}" -h -a _FillValue,,m,f,-1.e20 ${outfile}
          rm ${OUTDIR}/${YYYY_MM}/PVAP_2M_ts_tmp.nc ${OUTDIR}/${YYYY_MM}/PS_QV_ts.nc

        elif [ -f ${infile3} -a -f ${infile4} ] ; then
          cp ${infile3} ${OUTDIR}/${YYYY_MM}/T_RELHUM_ts.nc
          "${NCKS[@]}" -A ${infile4} ${OUTDIR}/${YYYY_MM}/T_RELHUM_ts.nc

          # Verify if RELHUM_2M is present
          "${NCKS[@]}" -m -v ARELHUM_2M ${OUTDIR}/${YYYY_MM}/T_RELHUM_ts.nc
          "${NCAP2[@]}" -O -s "PVAP_2M=AT_2M-999999" ${OUTDIR}/${YYYY_MM}/T_RELHUM_ts.nc ${OUTDIR}/${YYYY_MM}/T_RELHUM_ts.nc
          "${NCAP2[@]}" -O -s 'where ( AT_2M >=273.15 ) PVAP_2M=float(6.112*ARELHUM_2M*exp(17.62*(AT_2M-273.15)/(AT_2M-30.03))); elsewhere PVAP_2M=float(6.112*ARELHUM_2M*exp(22.46*(AT_2M-273.15)/(AT_2M-0.53))); ' ${OUTDIR}/${YYYY_MM}/T_RELHUM_ts.nc ${OUTDIR}/${YYYY_MM}/PVAP_2M_ts_tmp.nc
          "${NCKS[@]}" -h -O -v PVAP_2M,lon,lat,rotated_pole ${OUTDIR}/${YYYY_MM}/PVAP_2M_ts_tmp.nc ${outfile}
          "${NCATTED[@]}" -h -a standard_name,PVAP_2M,m,c,"water_vapour_partial_pressure_in_air" ${outfile}
          "${NCATTED[@]}" -h -a units,PVAP_2M,m,c,"Pa" ${outfile}
          "${NCATTED[@]}" -h -a long_name,PVAP_2M,m,c,"water vapour partial pressure in 2m" ${outfile}
          "${NCATTED[@]}" -h -a _FillValue,,m,f,-1.e20 ${outfile}
          rm ${OUTDIR}/${YYYY_MM}/PVAP_2M_ts_tmp.nc ${outfile}_grid ${OUTDIR}/${YYYY_MM}/T_RELHUM_ts.nc

        else
          echo "Input fields PS+QV_2M or T_2M+RELHUM_2M for the water vapour partial pressure PVAP_2M are missing"
        fi
      fi
      ;;

    'APOTEVAP_S')
      # calculation of potential evapotranspiration
      echo calculate APOTEVAP_S ...
      cd ${OUTDIR}/${YYYY_MM}
      "${PYTHON[@]}" ${PFDIR}/${EXPID}/scripts/calc_potevap_s.py ${OUTDIR}/${YYYY_MM}/
      "${NCATTED[@]}" -h -a coordinates,,d,, ${OUTDIR}/${YYYY_MM}/APOTEVAP_S_ts.nc
      "${NCATTED[@]}" -h -a coordinates,APOTEVAP_S,c,c,"lon lat height_2m" ${OUTDIR}/${YYYY_MM}/APOTEVAP_S_ts.nc
      "${NCWA[@]}" -O -a string1 ${OUTDIR}/${YYYY_MM}/APOTEVAP_S_ts.nc ${OUTDIR}/${YYYY_MM}/APOTEVAP_S_ts.tmp.nc

      # -- Correct record variable
      "${NCECAT[@]}" -h -O ${OUTDIR}/${YYYY_MM}/APOTEVAP_S_ts.tmp.nc ${OUTDIR}/${YYYY_MM}/APOTEVAP_S_ts.tmp.nc
      "${NCPDQ[@]}" -O -a time,record ${OUTDIR}/${YYYY_MM}/APOTEVAP_S_ts.tmp.nc ${OUTDIR}/${YYYY_MM}/APOTEVAP_S_ts.tmp.nc
      "${NCWA[@]}" -O -a record ${OUTDIR}/${YYYY_MM}/APOTEVAP_S_ts.tmp.nc ${OUTDIR}/${YYYY_MM}/APOTEVAP_S_ts.tmp.nc
      "${NCATTED[@]}" -h -a cellmethods,APOTEVAP_S,m,c,'time: sum' -a cellmethods,rotated_pole,d,, ${OUTDIR}/${YYYY_MM}/APOTEVAP_S_ts.tmp.nc
      mv ${OUTDIR}/${YYYY_MM}/APOTEVAP_S_ts.tmp.nc ${OUTDIR}/${YYYY_MM}/APOTEVAP_S_ts.nc
      ;;

    'RUNOFF_S_corr')
      # correction of runoff
      echo calculate RUNOFF_S_corr ...

      infile1=${OUTDIR}/${YYYY_MM}/RUNOFF_S_ts.nc
      infile2=${OUTDIR}/${YYYY_MM}/RUNOFF_S_T_8_ts.nc
      infile4=${OUTDIR}/${EXPID}_c.nc
      outfile=${OUTDIR}/${YYYY_MM}/RUNOFF_S_uncorr_ts.nc
      frlake_thrld=0.05
      [ -e ${outfile} ] && cp ${outfile} ${infile1} # copy of original runoff data is case of repairement runs of post
      #if [ ! -e ${outfile} ] ; then
        #if [ -e tmp${EXPID}${YYYY}${MM}RUNOFF_S.nc ] && rm tmp${EXPID}${YYYY}${MM}RUNOFF_S.nc
        "${CDO[@]}" merge ${infile1}  ${infile2} tmp${EXPID}${YYYY}${MM}RUNOFF_S.nc
        "${NCKS[@]}" -A -v FR_LAND,FR_LAKE $infile4 tmp${EXPID}${YYYY}${MM}RUNOFF_S.nc
        ## for complete lake grid points and mixed land/lake points the RUNOFF_S is corrected by the lake portion
        "${CDO[@]}" -expr,"RUNOFF_S=(FR_LAKE >= 1)? 0 : ((FR_LAKE > ${frlake_thrld})? (RUNOFF_S*(FR_LAND+FR_LAKE)-RUNOFF_S_T_8*FR_LAKE)/FR_LAND : RUNOFF_S ) " tmp${EXPID}${YYYY}${MM}RUNOFF_S.nc tmp${EXPID}${YYYY}${MM}RUNOFF_S_corr.nc

        mv $infile1 $outfile

        "${NCKS[@]}" -h -O -v RUNOFF_S,lat,lon,rotated_pole tmp${EXPID}${YYYY}${MM}RUNOFF_S_corr.nc ${infile1}
        "${NCATTED[@]}" -h -a long_name,RUNOFF_S,m,c,"weighted surface water runoff (corrected for lake fraction > 5%: water which is leaving the land portion)" -a standard_name,RUNOFF_S,o,c,"surface_runoff_amount" -a cell_methods,RUNOFF_S,o,c,'time: sum' ${infile1}

        #echo tmp${EXPID}${YYYY}${MM}RUNOFF_S.nc tmp${EXPID}${YYYY}${MM}RUNOFF_S_corr.nc
        rm tmp${EXPID}${YYYY}${MM}RUNOFF_S.nc tmp${EXPID}${YYYY}${MM}RUNOFF_S_corr.nc
      ##fi
      ;;

    'RUNOFF_T')
      # total runoff
      echo calculate RUNOFF_T ...
      infile1=${OUTDIR}/${YYYY_MM}/RUNOFF_S_ts.nc
      infile2=${OUTDIR}/${YYYY_MM}/RUNOFF_G_ts.nc
      outfile=${OUTDIR}/${YYYY_MM}/RUNOFF_T_ts.nc
      if [ ! -e ${outfile} ] ; then
        if [ -f ${infile1} -a -f ${infile2} ] ; then
          cp  ${infile1} tmp${EXPID}${YYYY}${MM}RUNOFF_T.nc
          "${NCKS[@]}" -h -A -v RUNOFF_G ${infile2} tmp${EXPID}${YYYY}${MM}RUNOFF_T.nc
          "${NCAP2[@]}" -O -s "RUNOFF_T=RUNOFF_S+RUNOFF_G" tmp${EXPID}${YYYY}${MM}RUNOFF_T.nc tmp${EXPID}${YYYY}${MM}RUNOFF_T.nc
          "${NCKS[@]}" -h -O -v RUNOFF_T,lat,lon,rotated_pole tmp${EXPID}${YYYY}${MM}RUNOFF_T.nc ${outfile}
          "${NCATTED[@]}" -h -a long_name,RUNOFF_T,m,c,"total runoff" -a standard_name,RUNOFF_T,o,c,"total_runoff_amount"  -a cell_methods,RUNOFF_T,o,c,'time: sum' ${outfile}
          rm tmp${EXPID}${YYYY}${MM}RUNOFF_T.nc
        else
          echo "Input fields " RUNOFF_S " and/or " RUNOFF_G " for calculating " RUNOFF_T " are missing"
        fi
      fi
      ;;

   'SOD_S')
      # total downward sw radiation at the surface
      echo calculate SOD_S ...
      infile1=${OUTDIR}/${YYYY_MM}/SOBS_RAD_ts.nc
      infile2=${OUTDIR}/${YYYY_MM}/SODIFU_S_ts.nc
      outfile=${OUTDIR}/${YYYY_MM}/SOD_S_ts.nc
      if [ ! -e ${outfile} ] ; then
        if [ -f ${infile1} -a -f ${infile2} ] ; then
          cp  ${infile1} tmp${EXPID}${YYYY}${MM}SOD_S.nc
          "${NCKS[@]}" -h -A -v SODIFU_S ${infile2} tmp${EXPID}${YYYY}${MM}SOD_S.nc
          "${NCAP2[@]}" -O -s "SOD_S=SOBS_RAD+SODIFU_S" tmp${EXPID}${YYYY}${MM}SOD_S.nc tmp${EXPID}${YYYY}${MM}SOD_S.nc
          "${NCKS[@]}" -h -O -v SOD_S,lat,lon,rotated_pole tmp${EXPID}${YYYY}${MM}SOD_S.nc ${outfile}
          "${NCATTED[@]}" -h -a long_name,SOD_S,m,c,"total downward sw radiation at the surface" -a standard_name,SOD_S,o,c,"surface_downwelling_shortwave_flux_in_air" ${outfile}
          rm tmp${EXPID}${YYYY}${MM}SOD_S.nc
        else
          echo "Input fields " SOBS_RAD " and/or " SODIFU_S " for calculating " SOD_S " are missing"
        fi
      fi
      ;;

    'SODIRD_S')
      # solar direct downward flux at the surface
      echo calculate SODIRD_S ...
      infile1=${OUTDIR}/${YYYY_MM}/SOBS_RAD_ts.nc
      infile2=${OUTDIR}/${YYYY_MM}/SODIFU_S_ts.nc
      infile3=${OUTDIR}/${YYYY_MM}/SODIFD_S_ts.nc
      outfile=${OUTDIR}/${YYYY_MM}/SODIRD_S_ts.nc
      if [[ -f ${infile1} ]] && [[ -f ${infile2} ]] && [[ -f ${infile3} ]]
      then
        "${CDO[@]}" -s add ${infile1} -sub ${infile2} ${infile3} ${outfile}
        "${NCRENAME[@]}" -h -v SOBS_RAD,SODIRD_S ${outfile}
        "${NCATTED[@]}" -h -a standard_name,SODIRD_S,m,c,"surface_direct_downwelling_shortwave_flux_in_air" ${outfile}
        "${NCATTED[@]}" -h -a long_name,SODIRD_S,m,c,"surface downward direct solar radiation" ${outfile}
        "${NCATTED[@]}" -h -a cell_methods,SODIRD_S,m,c,"time: point" ${outfile}

        # cdo removes the time_bnds units, create it again with the following command
        #KK "${NCATTED[@]}" -h -a units,time_bnds,o,c,"$("${CFU[@]}" get_attval ${OUTDIR}/${YYYY_MM}/SOBS_RAD_ts.nc time units)" ${outfile}
      else
        echo "Input fields SOBS_RAD and/or SODIFU_S and/or SODIFD_S for calcu+lating solar direct downward flux at the surface SODIRD_S are missing"
      fi
      ;;

    'SP_10M')
      #  wind speed in 10m height
      echo calculate SP_10M ...
      uvresfile=UV_10M_ts.nc
      varname=SP_10M
      outfile=${OUTDIR}/${YYYY_MM}/${varname}_ts.nc
      infile1=${OUTDIR}/${YYYY_MM}/U_10M_ts.nc
      infile2=${OUTDIR}/${YYYY_MM}/V_10M_ts.nc
      if [ ! -e ${outfile} ] ; then
        if [ -f ${infile1} -a -f ${infile2} ] ; then
          cp  ${infile1} ${uvresfile}
          "${NCKS[@]}" -h -A -v V_10M ${infile2} ${uvresfile}
          "${CDO[@]}" -s expr,${varname}'=(U_10M^2+V_10M^2)^0.5;' ${uvresfile} ${outfile}
          #... correct CDO created netCDF
          cdocor U_10M ${infile1} ${varname} ${outfile}
          "${NCATTED[@]}" -h -O \
            -a standard_name,${varname},o,c,'wind_speed' \
            -a long_name,${varname},o,c,'wind speed at 10m height' \
            -a cell_methods,${varname},o,c,'time: point' \
            ${outfile}
          rm ${uvresfile}
          echo "Calculated wind speed at 10m height."
        else
          echo "Input fields U_10 and/or V_10M for calculating wind speed at 10m height are missing"
        fi
      fi
      ;;

    'TOT_SNOW')
      # total snowfall
      echo calculate TOT_SNOW ...
      infile1=${OUTDIR}/${YYYY_MM}/SNOW_GSP_ts.nc
      infile2=${OUTDIR}/${YYYY_MM}/SNOW_CON_ts.nc
      outfile=${OUTDIR}/${YYYY_MM}/TOT_SNOW_ts.nc
      if [ ! -e ${outfile} ] ; then
        if [ -f ${infile1} -a -f ${infile2} ] ; then
          cp  ${infile1} tmp${EXPID}${YYYY}${MM}TOT_SNOW.nc
          "${NCKS[@]}" -h -A -v SNOW_CON ${infile2} tmp${EXPID}${YYYY}${MM}TOT_SNOW.nc
          "${NCAP2[@]}" -O -s "TOT_SNOW=SNOW_GSP+SNOW_CON" tmp${EXPID}${YYYY}${MM}TOT_SNOW.nc tmp${EXPID}${YYYY}${MM}TOT_SNOW.nc
          "${NCKS[@]}" -h -O -v TOT_SNOW,lat,lon,rotated_pole tmp${EXPID}${YYYY}${MM}TOT_SNOW.nc ${outfile}
          "${NCATTED[@]}" -h -a long_name,TOT_SNOW,m,c,"total snowfall" -a standard_name,TOT_SNOW,o,c,"total_snowfall_amount" ${outfile}
          rm tmp${EXPID}${YYYY}${MM}TOT_SNOW.nc
        else
          echo "Input fields " SNOW_GSP " and/or " SNOW_CON " for calculating " TOT_SNOW " are missing"
        fi
      fi
      ;;

    'TQW')
      # vertical integrated cloud condensed water
      echo calculate TQW ...
      infile1=${OUTDIR}/${YYYY_MM}/TQC_ts.nc
      infile2=${OUTDIR}/${YYYY_MM}/TQI_ts.nc
      outfile=${OUTDIR}/${YYYY_MM}/TQW_ts.nc
      if [ ! -e ${outfile} ] ; then
        if [ -f ${infile1} -a -f ${infile2} ] ; then
          cp  ${infile1} tmp${EXPID}${YYYY}${MM}TQW.nc
          "${NCKS[@]}" -h -A -v TQI ${infile2} tmp${EXPID}${YYYY}${MM}TQW.nc
          "${NCAP2[@]}" -O -s "TQW=TQC+TQI" tmp${EXPID}${YYYY}${MM}TQW.nc tmp${EXPID}${YYYY}${MM}TQW.nc
          "${NCKS[@]}" -h -O -v TQW,lat,lon,rotated_pole tmp${EXPID}${YYYY}${MM}TQW.nc ${outfile}
          "${NCATTED[@]}" -h -a long_name,TQW,m,c,"vertical integrated cloud condensed water" -a standard_name,TQW,o,c,"atmosphere_cloud_condensed_water_content" ${outfile}
          rm tmp${EXPID}${YYYY}${MM}TQW.nc
        else
          echo "Input fields " TQC " and/or " TQI " for calculating " TQW " are missing"
        fi
      fi
      ;;

    *)
      echo ATTENTION: ${1} is not a valid choice, action skipped
    ;;

  esac

}

################################################################################
# additional quantities on p-level

function timeseriesap {

  case ${1} in

    'SP')
      # wind speed on p-levels
      echo calculate SP on p-levels ...
      declare -p PLEVS=("${!2}") > /dev/null
      VARNAME=SP
      NPLEV=0
      while [[ ${NPLEV} -lt ${#PLEVS[@]} ]]
      do
        PLEV=$("${PYTHON[@]}" -c "print(int(${PLEVS[${NPLEV}]}))")
        INFILE1=${OUTDIR}/${YYYY_MM}/U${PLEV}p_ts.nc
        INFILE2=${OUTDIR}/${YYYY_MM}/V${PLEV}p_ts.nc
        OUTFILE=${OUTDIR}/${YYYY_MM}/${VARNAME}${PLEV}p_ts.nc
        UVTMPFILE=${OUTDIR}/${YYYY_MM}/tmp_SPUV${PLEV}p_ts.nc
        if [ ! -e ${OUTFILE} ] ; then
          if [ -f ${INFILE1} -a -f ${INFILE2} ] ; then
            cp  ${INFILE1} ${UVTMPFILE}
            "${NCKS[@]}" -h -A -v V ${INFILE2} ${UVTMPFILE}
            "${CDO[@]}" -s expr,${VARNAME}'=(U^2+V^2)^0.5;' ${UVTMPFILE} ${OUTFILE}
            #... correct CDO created netCDF
            cdocor U ${INFILE1} ${VARNAME} ${OUTFILE}
            "${NCATTED[@]}" -h -O \
              -a standard_name,${VARNAME},o,c,'wind_speed' \
              -a long_name,${VARNAME},o,c,'wind speed' \
              -a cell_methods,${VARNAME},o,c,'time: point' \
              ${OUTFILE}
            rm ${UVTMPFILE}
          else
            echo "ERROR: Input fields U"${PLEV}" and/or V"${PLEV}" for calculating wind speed at "${PLEV}"hPa are missing"
            echo ${INFILE1}
            echo ${INFILE2}
          fi
        else
          echo $(basename ${OUTFILE}) " already exists"
        fi
        let "NPLEV = NPLEV + 1"
      done
      ;;

    'DD')
      # wind direction on p-levels
      echo calculate DD on p-levels ...
      declare -p PLEVS=("${!2}") > /dev/null
      cd ${OUTDIR}/${YYYY_MM}
      VARNAME=DD
      NPLEV=0
      while [[ ${NPLEV} -lt ${#PLEVS[@]} ]]
      do
        PLEV=$("${PYTHON[@]}" -c "print(int(${PLEVS[$NPLEV]}))")
        INFILE1=U${PLEV}p_ts.nc
        INFILE2=V${PLEV}p_ts.nc
        OUTFILE=${VARNAME}${PLEV}p_ts.nc
        UVTMPFILE=tmp_DDUV_${PLEV}p_ts.nc
        if [ ! -e ${OUTFILE} ] ; then
          if [ -f ${INFILE1} -a -f ${INFILE2} ] ; then
            cp ${INFILE1} ${UVTMPFILE}
            "${NCKS[@]}" -h -A -v V ${INFILE2} ${UVTMPFILE}
          else
            echo "Input fields U"${PLEV}" and/or V"${PLEV}" for calculating wind direction at "${PLEV}"hPa are missing"
            let "NPLEV = NPLEV + 1"
            continue
          fi

          "${NCAP2[@]}" -O -s "${VARNAME}=float(45.0/atan(1.0)*atan2(U,V)+180.0)" ${UVTMPFILE} ${UVTMPFILE}
          "${NCKS[@]}" -h -O -v ${VARNAME},lat,lon,rotated_pole,pressure ${UVTMPFILE} ${OUTFILE}
          "${NCATTED[@]}" -h -O \
            -a standard_name,${VARNAME},o,c,'wind_from_direction' \
            -a long_name,${VARNAME},o,c,'wind direction' \
            -a units,${VARNAME},o,c,'deg' \
            -a coordinates,${VARNAME},o,c,'lon lat pressure' \
            -a cell_methods,${VARNAME},o,c,'time: point' \
            ${OUTFILE}
          rm ${UVTMPFILE}
          # "The wind direction at "${PLEV}"hPa was determined w.r.t. the geographical WGS84 system."
        else
          echo $(basename ${OUTFILE}) " already exists"
        fi
        let "NPLEV = NPLEV + 1"
      done
      ;;

    *)
      echo ATTENTION: ${1} is not a valid choice, action skipped
      ;;

  esac
}

################################################################################
# additional quantities on z-level

function timeseriesaz {

  case ${1} in

   'SP')
      # wind speed on height levels ...
      echo calculate SP on z-levels ...
      VARNAME=$1
      declare -p ZLEVS=("${!2}") > /dev/null
      SUFFIX=$3
      set -e
      if [ y${SUFFIX} == 'yNN' ]
      then
        HEIGHT=altitude
        NN=NN
      else
        HEIGHT=height
        NN=
      fi
      NZLEV=0
      while [[ ${NZLEV} -lt ${#ZLEVS[@]} ]]
      do
        ZLEV=$("${PYTHON[@]}" -c "print(int(${ZLEVS[${NZLEV}]}))")
        INFILE1=${OUTDIR}/${YYYY_MM}/U${ZLEV}z${NN}_ts.nc
        INFILE2=${OUTDIR}/${YYYY_MM}/V${ZLEV}z${NN}_ts.nc
        OUTFILE=${OUTDIR}/${YYYY_MM}/${VARNAME}${ZLEV}z${NN}_ts.nc
        UVTMPFILE=${OUTDIR}/${YYYY_MM}/tmp_SPUV${ZLEV}z${NN}.nc
        if [ ! -e ${OUTFILE} ] ; then
          if [ -f ${INFILE1} -a -f ${INFILE2} ] ; then
            cp  ${INFILE1} ${UVTMPFILE}
            "${NCKS[@]}" -h -A -v V ${INFILE2} ${UVTMPFILE}
            "${CDO[@]}" -s expr,${VARNAME}'=(U^2+V^2)^0.5;' ${UVTMPFILE} ${OUTFILE}

            #... correct CDO created netCDF
            cdocor U ${INFILE1} ${VARNAME} ${OUTFILE}
            "${NCATTED[@]}" -h -O \
              -a standard_name,${VARNAME},o,c,'wind_speed' \
              -a long_name,${VARNAME},o,c,'wind speed' \
              -a cell_methods,${VARNAME},o,c,'time: point' \
              ${OUTFILE}
            rm ${UVTMPFILE}
          else
            echo "ERROR: Input fields U"${ZLEV}" and/or V"${ZLEV}" for calculating wind speed at "${ZLEV}"m "${HEIGHT}" are missing"
            echo ${INFILE1}
            echo ${INFILE2}
          fi
        fi
        let "NZLEV = NZLEV + 1"
      done
      ;;

    'DD')
      # wind direction on z-levels ...
      echo calculate DD on z-levels
      VARNAME=$1
      cd ${OUTDIR}/${YYYY_MM}
      declare -p ZLEVS=("${!2}") > /dev/null
      SUFFIX=$3
      if [ y${SUFFIX} == 'yNN' ]
      then
        HEIGHT=altitude
        NN=NN
      else
        HEIGHT=height
        NN=
      fi

      NZLEV=0
      while [[ ${NZLEV} -lt ${#ZLEVS[@]} ]]
      do
        ZLEV=$("${PYTHON[@]}" -c "print(int(${ZLEVS[$NZLEV]}))")
        INFILE1=${OUTDIR}/${YYYY_MM}/U${ZLEV}z${NN}_ts.nc
        INFILE2=${OUTDIR}/${YYYY_MM}/V${ZLEV}z${NN}_ts.nc
        OUTFILE=${OUTDIR}/${YYYY_MM}/${VARNAME}${ZLEV}z${NN}_ts.nc
        UVTMPFILE=${OUTDIR}/${YYYY_MM}/tmp_DDUV${ZLEV}z${NN}.nc
        if [ ! -e ${OUTFILE} ] ; then
          if [ -f ${INFILE1} -a -f ${INFILE2} ] ; then
            cp ${INFILE1} ${UVTMPFILE}
            "${NCKS[@]}" -h -A -v V ${INFILE2} ${UVTMPFILE}
            "${NCAP2[@]}" -O -s "${VARNAME}=float(45.0/atan(1.0)*atan2(U,V)+180.0)" ${UVTMPFILE} ${UVTMPFILE}
            "${NCKS[@]}" -h -O -v ${VARNAME},lat,lon,rotated_pole,${HEIGHT} ${UVTMPFILE} ${OUTFILE}
            "${NCATTED[@]}" -h -O \
              -a standard_name,${VARNAME},o,c,'wind_from_direction' \
              -a long_name,${VARNAME},o,c,'wind direction' \
              -a units,${VARNAME},o,c,'deg' \
              -a cell_methods,${VARNAME},o,c,'time: point' \
              ${OUTFILE}

            #${NCATTED[@]} -h -O \
            #  -a standard_name,${VARNAME},o,c,'wind_from_direction' \
            #  -a long_name,${VARNAME},o,c,'wind direction' \
            #  -a units,${VARNAME},o,c,'deg' \
            #  -a coordinates,${VARNAME},o,c,'lon lat height' \
            #  -a cell_methods,${VARNAME},o,c,'time: point' \
            #  ${OUTFILE}

            rm ${UVTMPFILE}
            # "The wind direction at "${PLEV}"hPa was determined w.r.t. the geographical WGS84 system."
          else
            echo "ERROR: Input fields U"${ZLEV}" and/or V"${ZLEV}" for calculating wind direction at "${ZLEV}"m "${HEIGHT}" are missing"
            echo ${INFILE1}
            echo ${INFILE2}
          fi
        fi
        let "NZLEV = NZLEV + 1"
      done
      ;;

    *)
      echo ATTENTION: ${1} is not a valid choice, action skipped
      ;;

  esac
}

