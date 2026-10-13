MODULE mo_c2i_checks

!
!-------------------------------------------------------------------------------
!
! Description:
!    Perform checks
!     - on input files
!     - consistency of variables
!
!.....................................................
! Copyright 2021 Helmholtz-Zentrum Hereon
! Copyright 2019-2020 Helmholtz-Zentrum Geesthacht
! Licensed under the GNU License, Version 3.0
! (https://www.gnu.org/licenses/gpl-3.0.html)
! Author(s): Burkhardt Rockel (Hereon)
!.....................................................
!
!-------------------------------------------------------------------------------
!

USE netcdf

USE mo_c2i_data
USE mo_utils
USE mo_c2i_create

IMPLICIT NONE


contains
!=============================================================================

SUBROUTINE check_var_exist (ncid, varname, found, lonid, latid, timeid, nlon, nlat,filename)

! Description:
!    Checks if all necessary variables exists in the input file

  INTEGER ::  &
    istatus, ncid, varid, lonid, latid, timeid, nlon, nlat

  CHARACTER (LEN=*) ::  &
    varname, filename
    
  LOGICAL :: &
    found

  istatus = nf90_inq_varid(ncid, TRIM(varname), varid)
  IF (istatus == NF90_NOERR) THEN
    found = .TRUE.
  ENDIF

  IF ( found ) RETURN

  SELECT CASE (TRIM(varname))

    !... check whether T_SKIN exists. In case not, check whether T_S exists and create T_SKIN by this.
    CASE ('T_SKIN')
      istatus = nf90_inq_varid(ncid, 'T_S', varid)
      IF (istatus == NF90_NOERR) THEN
        found = .TRUE.
        PRINT *, '    INFO: T_SKIN not found in file: ',filename,', set to T_S'
        CALL create_3dvar (ncid, varid, lonid, latid, timeid, nlon, nlat, 'T_SKIN')
      ENDIF
   
    !... check whether FIS exists. In case not, check whether HSURF exists and create FIS by this.
    CASE ('FIS')
      istatus = nf90_inq_varid(ncid, 'HSURF', varid)
      IF (istatus == NF90_NOERR) THEN
        found = .TRUE.
        PRINT *, '    INFO: FIS not found in file: ',filename,', calculated from HSURF'
        CALL create_3dvar (ncid, varid, lonid, latid, timeid, nlon, nlat, 'FIS')
      ENDIF
   
    !... check whether LNSP exists. In case not, check whether PS exists and create LNSP by this.
    CASE ('LNSP')
      istatus = nf90_inq_varid(ncid, 'PS', varid)
      IF (istatus == NF90_NOERR) THEN
        found = .TRUE.
        PRINT *, '    INFO: LNSP not found in file: ',filename,', calculated from PS'
        CALL create_3dvar (ncid, varid, lonid, latid, timeid, nlon, nlat, 'LNSP')
      ENDIF
 
    !... check whether T_SNOW exists. In case not, check whether T_SKIN or T_S exists and create T_SNOW by this.
    CASE ('T_SNOW')
      istatus = nf90_inq_varid(ncid, 'T_SKIN', varid)
      IF (istatus == NF90_NOERR) THEN
        found = .TRUE.
        PRINT *, '    INFO: T_SNOW not found in file: ',filename,', set to T_SKIN'
        CALL create_3dvar (ncid, varid, lonid, latid, timeid, nlon, nlat, 'T_SNOW')
      ELSE
        istatus = nf90_inq_varid(ncid, 'T_S', varid)
        IF (istatus == NF90_NOERR) THEN
          found = .TRUE.
          PRINT *, '    INFO: T_SNOW not found in file: ',filename,', set to T_S'
          CALL create_3dvar (ncid, varid, lonid, latid, timeid, nlon, nlat, 'T_SNOW')
        ENDIF
      ENDIF 

    !... check whether SST exists. In case not, check whether T_SKIN or T_S exists and create SST by this.
    CASE ('SST')
      istatus = nf90_inq_varid(ncid, 'T_SKIN', varid)
      IF (istatus == NF90_NOERR) THEN
        found = .TRUE.
        PRINT *, '    INFO: SST not found in file: ',filename,', set to T_SKIN'
        CALL create_3dvar (ncid, varid, lonid, latid, timeid, nlon, nlat, 'SST')
      ELSE
        istatus = nf90_inq_varid(ncid, 'T_S', varid)
        IF (istatus == NF90_NOERR) THEN
          found = .TRUE.
          PRINT *, '    INFO: SST not found in file: ',filename,', set to T_S'
          CALL create_3dvar (ncid, varid, lonid, latid, timeid, nlon, nlat, 'SST')
        ENDIF
      ENDIF 
 
   
   END SELECT  

END SUBROUTINE check_var_exist

!=============================================================================

SUBROUTINE consistency_checks (ncid, lonid, latid, timeid, nlon, nlat, ntime)

! Description:
!    Checks consistencies of different variables
  
  INTEGER, INTENT(IN) :: &
    ncid, lonid, latid, timeid, nlon, nlat, ntime

  INTEGER :: &
    varid1, varid2, varid3, &
    istatus

  REAL, ALLOCATABLE :: &
    array3d1(:,:,:), &
    array3d2(:,:,:), &
    array3d3(:,:,:)

  ALLOCATE (array3d1(nlon,nlat,ntime),array3d2(nlon,nlat,ntime),array3d3(nlon,nlat,ntime))

!... in cases W_SNOW /= undef and T_SNOW == undef, set T_SNOW=T_SKIN
  
    istatus = nf90_inq_varid(ncid, 'W_SNOW', varid1)
    CALL handle_err(istatus,'nf90_inq_varid W_SNOW')
    istatus =  nf90_get_var(ncid, varid1, array3d1)
    CALL handle_err(istatus,'nf90_get_var W_SNOW')

    istatus = nf90_inq_varid(ncid, 'T_SNOW', varid2)
    CALL handle_err(istatus,'nf90_inq_varid T_SNOW')
    istatus =  nf90_get_var(ncid, varid2, array3d2)
    CALL handle_err(istatus,'nf90_get_var T_SNOW')

    istatus = nf90_inq_varid(ncid, 'T_SKIN', varid3)
    CALL handle_err(istatus,'nf90_inq_varid T_SKIN')
    istatus =  nf90_get_var(ncid, varid3, array3d3)
    CALL handle_err(istatus,'nf90_get_var T_SKIN')

    WHERE (array3d1 /= undef .AND. array3d2 == undef) array3d2 = array3d3
 !   WHERE (array3d1 == undef) array3d1 = 0.
 !   istatus =  nf90_put_var(ncid, varid1, array3d1)
 !   CALL handle_err(istatus,'nf90_put_var')
    istatus =  nf90_put_var(ncid, varid2, array3d2)
    CALL handle_err(istatus,'nf90_put_var')
    
    DEALLOCATE (array3d1, array3d2, array3d3)

END SUBROUTINE consistency_checks

!=============================================================================


END MODULE mo_c2i_checks
