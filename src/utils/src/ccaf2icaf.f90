PROGRAM ccaf2icaf

!
!-------------------------------------------------------------------------------
!
! Description:
!    Convert caf-files to ICON readable caf-files
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


! List of variables (m = mandatory, c = eventually to be created, o = optional)
! Initialization
! T m
! U m
! V m
! QV m
! LNSP m 
! FIS m
! FR_LAND m
! T_SKIN m
! W c  -- set to 0
! FI c lowest level -- set to FIS
! QC c -- set to 0
! QI c -- set to 0
! W_I c -- set to 0
! T_SNOW c -- T_SKIN
! W_SNOW c -- set to 0
! RHO_SNOW c -- set to 250 (where W_SNOW > 0)
! ALB_SNOW o
! T_SO -> STL1, STL2, STL3, STL4 c  -- calculate exponential from T_SKIN
! W_SO, W_SO_REL -> soil moisture index SMIL1, SMIL2, SMIL3, SMIL4 c  -- set to 0
! Z0 o
! 
! Boundary
! T m
! U m
! V m
! QV m
! LNPS m 
! W c -- set to 0
! QC c -- set to 0
! QI c -- set to 0
! FI c lowest level -- set to FIS

! importance : 
!     0 nice to have, but not necessary
!     1 needed by ICON, will get default values, if not in the input file
!     2 mandatory. If not found in the input file, job will fail

!... include netCDF f90 modules
USE netcdf

USE mo_c2i_data
USE mo_utils
USE mo_c2i_checks
USE mo_c2i_create
USE mo_c2i_soil

IMPLICIT NONE

INTEGER, PARAMETER :: &
  nvar=25

!-------------------------

CHARACTER (LEN=200) :: &
    ncfile, &              ! name of input netCDF file
    ifs_soil_type_file     ! file that holds IFS soil types (must be on the same grid as the input data)
    
CHARACTER (LEN=50) :: &
    carg             ! argument 
    
INTEGER :: &
    cmid             ! ID of coarse grid model
    
!-------------------------

INTEGER :: &
    itype_ini

TYPE ar_des
  CHARACTER (LEN=50)           :: name
  INTEGER                      :: importance
  LOGICAL                      :: found
END TYPE ar_des

TYPE (ar_des)     :: var(nvar)

CHARACTER (LEN=50)  :: &
  varname

INTEGER :: &
  i,    &
  ncid, nvdims, dimids(4), nvdimids(4), dims(4), &
  istatus, &
  nlon, nlat, ntime, nlevel, nlevel1, &
  lonid, latid, timeid, levelid, level1id, varid

LOGICAL :: &
  mandatory_exist, &
  lexist, found

REAL, ALLOCATABLE :: &
  array3d(:,:,:), &
  array4d(:,:,:,:)

mandatory_exist = .TRUE.

!... get command-line argument
  IF (iargc() < 2) THEN
    PRINT *, ' ERROR: too few arguments'
    PRINT *, ' Usage: ccaf2icaf <ncfile> <coarse grid model id> [<ifs_soil_type_file>]'
    STOP
  END IF

  CALL getarg(1, ncfile)
  CALL getarg(2, carg)
  READ(carg,*) cmid
  IF ((cmid == 2) .AND. iargc() < 3) THEN
    PRINT *, ' ERROR: too few arguments'
    PRINT *, ' Usage: ccaf2icaf <ncfile> <coarse grid model id> <ifs_soil_type_file>'
    STOP   
  ENDIF 
  IF ((cmid == 2) .AND. iargc() == 3) THEN
    CALL getarg(3, ifs_soil_type_file)
  ENDIF

!... check existence of input file
  INQUIRE(file=ncfile,exist=lexist)
  IF (.NOT. lexist) THEN
    PRINT *,'ERROR: ',TRIM(ncfile),' does not exist'
    STOP
  END IF

!... open netCDF file and get file ID
  istatus = nf90_open (TRIM(ncfile), NF90_WRITE, ncid)
  CALL handle_err(istatus,'nf90_open'//TRIM(ncfile))

!... get var IDs
   istatus = nf90_inq_dimid(ncid, 'lon', lonid)
   CALL handle_err(istatus,'nf90_inq_dimid lon')
   istatus = nf90_inquire_dimension(ncid, lonid, len = nlon)
   CALL handle_err(istatus,'nf90_inquire_dimension lon')
   istatus = nf90_inq_dimid(ncid, 'lat', latid)
   CALL handle_err(istatus,'nf90_inq_dimid lat')
   istatus = nf90_inquire_dimension(ncid, latid, len = nlat)
   CALL handle_err(istatus,'nf90_inquire_dimension lat')
   istatus = nf90_inq_dimid(ncid, 'time', timeid)
   CALL handle_err(istatus,'nf90_inq_dimid time')
   istatus = nf90_inquire_dimension(ncid, timeid, len = ntime)
   CALL handle_err(istatus,'nf90_inquire_dimension time')
   istatus = nf90_inq_dimid(ncid, 'level', levelid)
   CALL handle_err(istatus,'nf90_inq_dimid level')
   istatus = nf90_inquire_dimension(ncid, levelid, len = nlevel)
   CALL handle_err(istatus,'nf90_inquire_dimension level')
   istatus = nf90_inq_dimid(ncid, 'level1', level1id)
   CALL handle_err(istatus,'nf90_inq_dimid level1')
   istatus = nf90_inquire_dimension(ncid, level1id, len = nlevel1)
   CALL handle_err(istatus,'nf90_inquire_dimension level1')

   ALLOCATE (array3d(nlon, nlat,ntime),array4d(nlon, nlat, nlevel, ntime))


!  CALL create_level (ncid, levelid, nlevel, level1id, nlevel1)

  SELECT CASE (cmid)
  
  CASE (0)
    CALL create_default_soil_quantities (ncid, lonid, latid, timeid, nlon, nlat, ntime)

  CASE (1)
    CALL create_erainterim_soil_quantities (ncid, lonid, latid, timeid, nlon, nlat, ntime)

  CASE (2)
    CALL create_era5_soil_quantities (ncid, lonid, latid, timeid, nlon, nlat, ntime, ifs_soil_type_file)

  CASE default
    PRINT *, 'ERROR: invalid coarse grid model id'
    PRINT *, '       valid values:'
    PRINT *, '       0 general'
    PRINT *, '       1 ERAInterim reanalysis'
    PRINT *, '       2 ERA5 reanalysis'
    STOP 1

  END SELECT 

  var(:) = ar_des('          ', 0, .FALSE.)
  
  !                     name  importance  found
  var( 1)= ar_des('T          ',    2, .FALSE.)
  var( 2)= ar_des('U          ',    2, .FALSE.)
  var( 3)= ar_des('V          ',    2, .FALSE.)
  var( 4)= ar_des('QV         ',    2, .FALSE.)
  var( 5)= ar_des('LNSP       ',    2, .FALSE.)
  var( 6)= ar_des('FIS        ',    2, .FALSE.)
  var( 7)= ar_des('FR_LAND    ',    2, .FALSE.)
  var( 8)= ar_des('T_SKIN     ',    2, .FALSE.)
  
  var( 9)= ar_des('W          ',    1, .FALSE.)
  var(10)= ar_des('FI         ',    1, .FALSE.)
  var(11)= ar_des('QC         ',    1, .FALSE.)
  var(12)= ar_des('QI         ',    1, .FALSE.)
  var(13)= ar_des('QR         ',    1, .FALSE.)
  var(14)= ar_des('QS         ',    1, .FALSE.)
  var(15)= ar_des('W_I        ',    1, .FALSE.)
  var(16)= ar_des('T_SNOW     ',    1, .FALSE.)
  var(17)= ar_des('W_SNOW     ',    1, .FALSE.)
  var(18)= ar_des('RHO_SNOW   ',    1, .FALSE.)
  var(19)= ar_des('T_SO       ',    1, .FALSE.)
  var(20)= ar_des('W_SO       ',    1, .FALSE.)
  var(21)= ar_des('W_SO_REL   ',    1, .FALSE.)
  var(22)= ar_des('FR_SEA_ICE ',    1, .FALSE.)
  var(23)= ar_des('SST        ',    1, .FALSE.)
  
  var(24)= ar_des('ALB_SNOW   ',    0, .FALSE.)
  var(25)= ar_des('Z0         ',    0, .FALSE.)

! loop over nvar to check the existence of the variable

  DO i = 1, nvar

!  found = var(i)%found
!  varname = var(i)%name

   CALL check_var_exist (ncid, TRIM(var(i)%name), var(i)%found, lonid, latid, timeid, nlon, nlat, TRIM(ncfile))
!   CALL check_var_exist (ncid, TRIM(varname), found, lonid, latid, timeid, nlon, nlat)

   IF (var(i)%importance == 2 .AND. .NOT. var(i)%found) THEN
     PRINT *, "Mandatory quantity not found: ", TRIM(var(i)%name)
     mandatory_exist = .FALSE.
   ENDIF

!    SELECT CASE (TRIM(var(i)%name))
!      CASE ('PS')
!        istatus = nf90_inq_varid(ncid, 'PS', varid)
!        istatus =  nf90_get_var(ncid, varid, array3d)    
!        array3d = LOG(array3d)
!        istatus =  nf90_put_var(ncid, varid, array3d)    
!        istatus = nf90_rename_var(ncid, varid, 'LNSP')
!    END SELECT


  ENDDO
  
  IF (.NOT. mandatory_exist) THEN
    PRINT *, 'ERROR: not all mandatory quantities available'
    STOP
  ENDIF


! loop for creating and writing quantities with importance = 1
  DO i = 1, nvar

    IF ( var(i)%importance == 1 .AND. .NOT. var(i)%found) THEN
    
      SELECT CASE (TRIM(var(i)%name))
        CASE ('W', 'QC', 'QI', 'QR', 'QS')
        
          istatus = nf90_redef(ncid)
          CALL handle_err(istatus,'nf90_redef')
          istatus = nf90_def_var(ncid, TRIM(var(i)%name), NF90_FLOAT, (/ lonid, latid, levelid, timeid /), varid)
          CALL handle_err(istatus,'nf90_def_var '//TRIM(var(i)%name))
          array4d = 0.
          istatus = nf90_enddef(ncid)
          CALL handle_err(istatus,'nf90_enddef')
          istatus =  nf90_put_var(ncid, varid, array4d)    
          CALL handle_err(istatus,'nf90_put_var '//TRIM(var(i)%name))
        
        CASE ('W_I', 'W_SNOW', 'FR_SEA_ICE')

          istatus = nf90_redef(ncid)
          CALL handle_err(istatus,'nf90_redef')
          istatus = nf90_def_var(ncid, TRIM(var(i)%name), NF90_FLOAT, (/ lonid, latid, timeid /), varid)
          CALL handle_err(istatus,'nf90_def_var '//TRIM(var(i)%name))
          array3d = 0.
          istatus = nf90_enddef(ncid)
          CALL handle_err(istatus,'nf90_enddef')
          istatus =  nf90_put_var(ncid, varid, array3d)    
          CALL handle_err(istatus,'nf90_put_var '//TRIM(var(i)%name))

        CASE ('RHO_SNOW')
        
          istatus = nf90_redef(ncid)
          CALL handle_err(istatus,'nf90_redef')
          istatus = nf90_def_var(ncid, TRIM(var(i)%name), NF90_FLOAT, (/ lonid, latid, timeid /), varid)
          CALL handle_err(istatus,'nf90_def_var '//TRIM(var(i)%name))
          array3d = 250.
          istatus = nf90_enddef(ncid)
          CALL handle_err(istatus,'nf90_enddef')
          istatus =  nf90_put_var(ncid, varid, array3d)    
          CALL handle_err(istatus,'nf90_put_var '//TRIM(var(i)%name))
         
       
      END SELECT
        
    ENDIF

  ENDDO

  CALL consistency_checks (ncid, lonid, latid, timeid, nlon, nlat, ntime)

  CALL renamings (ncid)

  istatus = nf90_close (ncid)
  CALL handle_err(istatus,'nf90_close'//TRIM(ncfile))


END PROGRAM ccaf2icaf



