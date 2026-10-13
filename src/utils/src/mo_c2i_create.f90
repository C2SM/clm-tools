MODULE mo_c2i_create

!
!-------------------------------------------------------------------------------
!
! Description:
!     - create vertical levels
!     - create variables
!     - rename variables
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

IMPLICIT NONE

contains
!=============================================================================

SUBROUTINE create_level (ncid, levelid, nlevel, level1id, nlevel1)

! Description:
!    Create vertical levels

  INTEGER :: &
    ncid, levelid, nlevel, level1id, nlevel1

  REAL, ALLOCATABLE :: &
    level1(:), ak(:), bk(:), akm(:), bkm(:)

  INTEGER :: &
    k, levelvarid, level1varid, istatus, &
    akvarid, bkvarid, akmvarid, bkmvarid

    ALLOCATE (level1(nlevel1), ak(nlevel1), bk(nlevel1), akm(nlevel), bkm(nlevel))
    DO k = 1, nlevel1
      level1(k) = REAL(k)
    ENDDO

    istatus = nf90_redef(ncid)
!    istatus = nf90_def_var(ncid, 'level', NF90_DOUBLE, levelid, levelvarid)
!    istatus = nf90_put_att(ncid, levelvarid, "standard_name", "hybrid_sigma_pressure")
!    istatus = nf90_put_att(ncid, levelvarid, "long_name", "hybrid level at layer mid points")
!    istatus = nf90_put_att(ncid, levelvarid, "formula_terms", "ap: akm b: bkm ps: PS")
!    istatus = nf90_put_att(ncid, levelvarid, "units", "level")
!    istatus = nf90_put_att(ncid, levelvarid, "positive", "down")
    istatus = nf90_def_var(ncid, 'level1', NF90_DOUBLE, level1id, level1varid)
    CALL handle_err(istatus,'nf90_def_var level1')
    istatus = nf90_put_att(ncid, level1varid, "standard_name", "hybrid_sigma_pressure")
    CALL handle_err(istatus,'nf90_put_att standard_name level1')
    istatus = nf90_put_att(ncid, level1varid, "long_name", "hybrid level at layer edge points")
    CALL handle_err(istatus,'nf90_put_att long_name level1')
!    istatus = nf90_put_att(ncid, level1varid, "formula", "ak bk (mlev=ak+bk*aps)")
!    istatus = nf90_put_att(ncid, level1varid, "formula_terms", "ap: ak b bk ps:aps")
!    istatus = nf90_put_att(ncid, level1varid, "formula", "ak bk (mlev=ak+bk*PS)")
!_br test    istatus = nf90_put_att(ncid, level1varid, "formula_terms", "ap: ak b: bk ps: PS")
!_br test    CALL handle_err(istatus,'nf90_put_att formula_terms level1')
    istatus = nf90_put_att(ncid, level1varid, "units", "level")
    CALL handle_err(istatus,'nf90_put_att units level1')
    istatus = nf90_put_att(ncid, level1varid, "positive", "down")
    CALL handle_err(istatus,'nf90_put_att positive level1')

    istatus = nf90_inq_varid(ncid, 'ak', akvarid)
    CALL handle_err(istatus,'nf90_inq_varid ak not found')
!    IF (istatus /= NF90_NOERR) THEN
!      PRINT *, 'ERROR: ak not found'
!      STOP 1
!          istatus = nf90_def_var(ncid, 'akm', NF90_DOUBLE, levelid, akmvarid)
!          istatus = nf90_def_var(ncid, 'bkm', NF90_DOUBLE, levelid, bkmvarid)
!          istatus = nf90_inq_varid(ncid, 'ak', akvarid)
!          istatus = nf90_inq_varid(ncid, 'bk', bkvarid)
!          istatus = nf90_get_var(ncid, akvarid, ak)
!          istatus = nf90_get_var(ncid, bkvarid, bk)
!          DO k = 1, nlevel
!            akm(k) = (ak(k) + ak(k+1)) / 2.
!            bkm(k) = (bk(k) + bk(k+1)) / 2.
!          ENDDO
!    ENDIF
   
    istatus = nf90_enddef(ncid)
    CALL handle_err(istatus,'nf90_enddef')
    istatus =  nf90_put_var(ncid, levelvarid, level1(1:nlevel))
    CALL handle_err(istatus,'nf90_put_var level1')
!_br test    istatus =  nf90_put_var(ncid, level1varid, level1)
!    istatus =  nf90_put_var(ncid, akmvarid, akm)
!    istatus =  nf90_put_var(ncid, bkmvarid, bkm)

END SUBROUTINE create_level

!=============================================================================

SUBROUTINE create_3dvar (ncid, varid, lonid, latid, timeid, nlon, nlat, varname)
  
! Description:
!    Create several variables

  INTEGER, INTENT(IN) :: &
    ncid, varid, lonid, latid, timeid, nlon, nlat

  CHARACTER (LEN=*), INTENT(IN) :: &
    varname

  INTEGER :: &
    istatus, varid_out, varid_aux

  REAL, ALLOCATABLE :: &
    var(:,:,:), var_aux(:,:,:)

    ALLOCATE (var(nlon, nlat, 1), var_aux(nlon, nlat, 1))
    
    istatus =  nf90_get_var(ncid, varid, var)
    CALL handle_err(istatus,'nf90_get_var var')

    SELECT CASE (TRIM(varname))
      CASE ('LNSP')
        var = LOG(var)
      CASE ('FIS')
        var = 9.806 * var
      CASE ('SST')
         istatus = nf90_inq_varid(ncid, 'FR_LAND', varid_aux)
         CALL handle_err(istatus,'nf90_inq_varid FR_LAND')
         istatus =  nf90_get_var(ncid, varid_aux, var_aux)
         CALL handle_err(istatus,'nf90_get_var FR_LAND')
         WHERE (var_aux >= 0.5) var=undef
    END SELECT
    
    istatus = nf90_redef(ncid)
    CALL handle_err(istatus,'nf90_redef')
    istatus = nf90_def_var(ncid, TRIM(varname), NF90_FLOAT, (/ lonid, latid, timeid /), varid_out)
    CALL handle_err(istatus,'nf90_def_var '//TRIM(varname))
    istatus = nf90_put_att(ncid, varid_out, "_FillValue", undef)
    CALL handle_err(istatus,'nf90_put_att '//TRIM(varname))
    istatus = nf90_enddef(ncid)
    CALL handle_err(istatus,'nf90_enddef')
    istatus =  nf90_put_var(ncid, varid_out, var)
    CALL handle_err(istatus,'nf90_put_var'//TRIM(varname))

    DEALLOCATE (var)

END SUBROUTINE create_3dvar

!=============================================================================

SUBROUTINE renamings (ncid)
  
! Description:
!    Rename several variables

  INTEGER, INTENT(IN) :: &
    ncid

  INTEGER :: &
    varid

  INTEGER :: &
    varid1, varid2, varid3, &
    istatus


    istatus = nf90_redef(ncid)
    CALL handle_err(istatus,'nf90_redef')
    istatus = nf90_inq_varid(ncid, 'FR_LAND', varid)
    CALL handle_err(istatus,'nf90_inq_varid FR_LAND')
    istatus =  nf90_rename_var(ncid, varid, 'LSM')
    CALL handle_err(istatus,'nf90_rename_var FR_LAND to LSM')

    istatus = nf90_inq_varid(ncid, 'FIS', varid)
    CALL handle_err(istatus,'nf90_inq_varid FIS')
    istatus =  nf90_rename_var(ncid, varid, 'GEOP_ML')
    CALL handle_err(istatus,'nf90_rename_var FIS to GEOP_ML')

    istatus = nf90_inq_varid(ncid, 'T_SKIN', varid)
    CALL handle_err(istatus,'nf90_inq_varid T_SKIN')
    istatus =  nf90_rename_var(ncid, varid, 'SKT')
    CALL handle_err(istatus,'nf90_rename_var T_SKIN to SKT')

    istatus = nf90_inq_varid(ncid, 'FR_SEA_ICE', varid)
    CALL handle_err(istatus,'nf90_inq_varid FR_SEA_ICE')
    istatus =  nf90_rename_var(ncid, varid, 'SIC')
    CALL handle_err(istatus,'nf90_rename_var FR_SEA_ICE to SIC')

    istatus = nf90_inq_varid(ncid, 'LNSP', varid)
    CALL handle_err(istatus,'nf90_inq_varid LNSP')
    istatus =  nf90_rename_var(ncid, varid, 'LNPS')
    CALL handle_err(istatus,'nf90_rename_var LNSP to LNPS')

END SUBROUTINE renamings

!=============================================================================

END MODULE mo_c2i_create
