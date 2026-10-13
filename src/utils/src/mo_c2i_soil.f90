MODULE mo_c2i_soil

!
!-------------------------------------------------------------------------------
!
! Description:
!   Create soil quantities SLTn and SMIn
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

SUBROUTINE create_erainterim_soil_quantities (ncid, lonid, latid, timeid, nlon, nlat, ntime)

! Description:
!   Create soil quantities SLTn and SMIn for ERAInterim input
!
!
! https://www.ecmwf.int/en/forecasts/documentation-and-support/evolution-ifs/cycles/change-soil-hydrology-scheme-ifs-cycle
!  VW_SO = W_SO_REL * 0.472

  INTEGER, INTENT(IN) :: &
    ncid, lonid, latid, timeid, nlon, nlat, ntime
        
  REAL :: &
    soil_depth(4)
    
  REAL, ALLOCATABLE :: &
    t_so(:,:,:,:), &
    w_so_rel(:,:,:,:), &
    fr_land(:,:,:,:)

  INTEGER, ALLOCATABLE :: &
    soil_type(:,:,:,:) 

  REAL, ALLOCATABLE :: &
    smil(:,:,:,:)
   
  INTEGER :: &
    istatus, varid, dp1d, dp2d, dp3d, dp4d, &
    dp1id, dp2id, dp3id, dp4id, &
    dp1varid, dp2varid, dp3varid, dp4varid, &
    smil1varid, smil2varid, smil3varid, smil4varid, &
    stl1varid, stl2varid, stl3varid, stl4varid, &
    ncid_soil_type
    
  LOGICAL :: &
    lexist

    ALLOCATE (t_so(nlon,nlat,4,1), w_so_rel(nlon,nlat,4,1), soil_type(nlon, nlat,4,1), smil(nlon, nlat, 4, 1), fr_land(nlon, nlat, 4, 1))

!... get soil1, T_SO, W_SO_REL from caf-file
    istatus = nf90_inq_varid(ncid, 'soil1', varid)
    CALL handle_err(istatus,'nf90_inq_varid soil1 not found')
    istatus =  nf90_get_var(ncid, varid, soil_depth)
    CALL handle_err(istatus,'nf90_get_var soil1')

    istatus = nf90_inq_varid(ncid, 'T_SO', varid)
    CALL handle_err(istatus,'nf90_inq_varid T_SO not found')
    istatus =  nf90_get_var(ncid, varid, t_so)
    CALL handle_err(istatus,'nf90_get_var T_SO')

    istatus = nf90_inq_varid(ncid, 'W_SO_REL', varid)
    CALL handle_err(istatus,'nf90_inq_varid W_SO_REL not found')
    istatus =  nf90_get_var(ncid, varid, w_so_rel)
    CALL handle_err(istatus,'nf90_get_var W_SO_REL')
    w_so_rel(:,:,:,:) = w_so_rel(:,:,:,:) * 0.472

    istatus = nf90_inq_varid(ncid, 'FR_LAND', varid)
    CALL handle_err(istatus,'nf90_inq_varid FR_LAND  not found')
    istatus =  nf90_get_var(ncid, varid, fr_land(:,:,1,1))
    CALL handle_err(istatus,'nf90_get_var FR_LAND')
    fr_land(:,:,2,1) = fr_land(:,:,1,1)
    fr_land(:,:,3,1) = fr_land(:,:,1,1)
    fr_land(:,:,4,1) = fr_land(:,:,1,1)

!... compute SMIL
    
!      smil = (w_so_rel-0.171)/(0.323-0.171) = (w_so_rel-0.171)/(0.152)
!    smil(:,:,:,:) = (w_so_rel-0.171)/(0.152)
     WHERE (fr_land < 0.5) 
       smil = undef
!       t_so = undef
     ELSE WHERE
       smil = (w_so_rel-0.171)/(0.152)
     END WHERE

    istatus = nf90_redef(ncid)
    CALL handle_err(istatus,'nf90_redef')
    istatus = nf90_def_dim(ncid, 'depth', 1, dp1id)
    CALL handle_err(istatus,'nf90_def_dim depth')
    istatus = nf90_def_dim(ncid, 'depth_2', 1, dp2id)
    CALL handle_err(istatus,'nf90_def_dim depth_2')
    istatus = nf90_def_dim(ncid, 'depth_3', 1, dp3id)
    CALL handle_err(istatus,'nf90_def_dim depth_3')
    istatus = nf90_def_dim(ncid, 'depth_4', 1, dp4id)
    CALL handle_err(istatus,'nf90_def_dim depth_4')
    
    istatus = nf90_def_var(ncid, 'depth', NF90_DOUBLE, dp1id, dp1varid)
    CALL handle_err(istatus,'nf90_def_var depth')
    istatus = nf90_def_var(ncid, 'depth_2', NF90_DOUBLE, dp2id, dp2varid)
    CALL handle_err(istatus,'nf90_def_var depth_2')
    istatus = nf90_def_var(ncid, 'depth_3', NF90_DOUBLE, dp3id, dp3varid)
    CALL handle_err(istatus,'nf90_def_var depth_3')
    istatus = nf90_def_var(ncid, 'depth_4', NF90_DOUBLE, dp4id, dp4varid)
    CALL handle_err(istatus,'nf90_def_var depth_4')
    
    istatus = nf90_enddef(ncid)
    CALL handle_err(istatus,'nf90_enddef')
    istatus =  nf90_put_var(ncid, dp1varid, soil_depth(1))
    CALL handle_err(istatus,'nf90_put_var depth')
    istatus =  nf90_put_var(ncid, dp2varid, soil_depth(2))
    CALL handle_err(istatus,'nf90_put_var depth_2')
    istatus =  nf90_put_var(ncid, dp3varid, soil_depth(3))
    CALL handle_err(istatus,'nf90_put_var depth_3')
    istatus =  nf90_put_var(ncid, dp4varid, soil_depth(4))
    CALL handle_err(istatus,'nf90_put_var depth_4')

    istatus = nf90_redef(ncid)
    CALL handle_err(istatus,'nf90_redef')
    istatus = nf90_def_var(ncid, 'STL1', NF90_FLOAT, (/ lonid, latid, dp1id, timeid /), stl1varid)
    CALL handle_err(istatus,'nf90_def_var STL1')
    istatus = nf90_put_att(ncid, stl1varid, "_FillValue", undef)
    CALL handle_err(istatus,'nf90_put_att STL1')
    istatus = nf90_def_var(ncid, 'STL2', NF90_FLOAT, (/ lonid, latid, dp2id, timeid /), stl2varid)
    CALL handle_err(istatus,'nf90_def_var STL2')
    istatus = nf90_put_att(ncid, stl2varid, "_FillValue", undef)
    CALL handle_err(istatus,'nf90_put_att STL2')
    istatus = nf90_def_var(ncid, 'STL3', NF90_FLOAT, (/ lonid, latid, dp3id, timeid /), stl3varid)
    CALL handle_err(istatus,'nf90_def_var STL3')
    istatus = nf90_put_att(ncid, stl3varid, "_FillValue", undef)
    CALL handle_err(istatus,'nf90_put_att STL3')
    istatus = nf90_def_var(ncid, 'STL4', NF90_FLOAT, (/ lonid, latid, dp4id, timeid /), stl4varid)
    CALL handle_err(istatus,'nf90_def_var STL4')
    istatus = nf90_put_att(ncid, stl4varid, "_FillValue", undef)
    CALL handle_err(istatus,'nf90_put_att STL4')

    istatus = nf90_enddef(ncid)
    CALL handle_err(istatus,'enddef')
    istatus =  nf90_put_var(ncid, stl1varid, t_so(:,:,1,1))
    CALL handle_err(istatus,'nf90_put_var STL1')
    istatus =  nf90_put_var(ncid, stl2varid, t_so(:,:,2,1))
    CALL handle_err(istatus,'nf90_put_var STL2')
    istatus =  nf90_put_var(ncid, stl3varid, t_so(:,:,3,1))
    CALL handle_err(istatus,'nf90_put_var STL3')
    istatus =  nf90_put_var(ncid, stl4varid, t_so(:,:,4,1))
    CALL handle_err(istatus,'nf90_put_var STL4')

    

    istatus = nf90_redef(ncid)
    CALL handle_err(istatus,'nf90_redef')
    istatus = nf90_def_var(ncid, 'SMIL1', NF90_FLOAT, (/ lonid, latid, dp1id, timeid /), smil1varid)
    CALL handle_err(istatus,'nf90_def_var SMIL1')
    istatus = nf90_put_att(ncid, smil1varid, "_FillValue", undef)
    CALL handle_err(istatus,'nf90_put_att SMIL1')
    istatus = nf90_def_var(ncid, 'SMIL2', NF90_FLOAT, (/ lonid, latid, dp2id, timeid /), smil2varid)
    CALL handle_err(istatus,'nf90_def_var SMIL2')
    istatus = nf90_put_att(ncid, smil2varid, "_FillValue", undef)
    CALL handle_err(istatus,'nf90_put_att SMIL2')
    istatus = nf90_def_var(ncid, 'SMIL3', NF90_FLOAT, (/ lonid, latid, dp3id, timeid /), smil3varid)
    CALL handle_err(istatus,'nf90_def_var SMIL3')
    istatus = nf90_put_att(ncid, smil3varid, "_FillValue", undef)
    CALL handle_err(istatus,'nf90_put_att SMIL3')
    istatus = nf90_def_var(ncid, 'SMIL4', NF90_FLOAT, (/ lonid, latid, dp4id, timeid /), smil4varid)
    CALL handle_err(istatus,'nf90_def_var SMIL4')
    istatus = nf90_put_att(ncid, smil4varid, "_FillValue", undef)
    CALL handle_err(istatus,'nf90_put_att SMIL4')

    istatus = nf90_enddef(ncid)
    CALL handle_err(istatus,'nf90_enddef')
    istatus =  nf90_put_var(ncid, smil1varid, smil(:,:,1,1))
    CALL handle_err(istatus,'nf90_put_var SMIL1')
    istatus =  nf90_put_var(ncid, smil2varid, smil(:,:,2,1))
    CALL handle_err(istatus,'nf90_put_var SMIL2')
    istatus =  nf90_put_var(ncid, smil3varid, smil(:,:,3,1))
    CALL handle_err(istatus,'nf90_put_var SMIL3')
    istatus =  nf90_put_var(ncid, smil4varid, smil(:,:,4,1))
    CALL handle_err(istatus,'nf90_put_var SMIL4')

    
    DEALLOCATE (t_so, w_so_rel, soil_type, smil, fr_land)

END SUBROUTINE create_erainterim_soil_quantities

!=============================================================================

SUBROUTINE create_era5_soil_quantities (ncid, lonid, latid, timeid, nlon, nlat, ntime, ifs_soil_type_file)

! Description:
!   Create soil quantities SLTn and SMIn for ERA5 input
!
! https://www.ecmwf.int/en/forecasts/documentation-and-support/evolution-ifs/cycles/change-soil-hydrology-scheme-ifs-cycle
!  VW_SO = W_SO_REL * 0.472

  INTEGER, INTENT(IN) :: &
    ncid, lonid, latid, timeid, nlon, nlat, ntime
    
  CHARACTER (LEN=200), INTENT(IN) :: ifs_soil_type_file
    
  REAL :: &
    soil_depth(4)
    
  REAL, ALLOCATABLE :: &
    t_so(:,:,:,:), &
    w_so_rel(:,:,:,:), &
    fr_land(:,:,:,:)

  INTEGER, ALLOCATABLE :: &
    soil_type(:,:,:,:) 

  REAL, ALLOCATABLE :: &
    smil(:,:,:,:)
   
  REAL :: &
    pwp(6)   , &
    fc(6)
  
  INTEGER :: &
    istatus, varid, dp1d, dp2d, dp3d, dp4d, &
    dp1id, dp2id, dp3id, dp4id, &
    dp1varid, dp2varid, dp3varid, dp4varid, &
    smil1varid, smil2varid, smil3varid, smil4varid, &
    stl1varid, stl2varid, stl3varid, stl4varid, &
    ncid_soil_type
    
  LOGICAL :: &
    lexist

    pwp = (/ 0.059, 0.151, 0.133, 0.279, 0.335, 0.267 /)
    fc =  (/ 0.242, 0.346, 0.382, 0.448, 0.541, 0.662 /)

    ALLOCATE (t_so(nlon,nlat,4,1), w_so_rel(nlon,nlat,4,1), soil_type(nlon, nlat,4,1), smil(nlon, nlat, 4, 1), fr_land(nlon, nlat, 4, 1))

!... get soil1, T_SO, W_SO_REL from caf-file
    istatus = nf90_inq_varid(ncid, 'soil1', varid)
    CALL handle_err(istatus,'nf90_inq_varid soil1 not found')
    istatus =  nf90_get_var(ncid, varid, soil_depth)
    CALL handle_err(istatus,'nf90_get_var soil1')

    istatus = nf90_inq_varid(ncid, 'T_SO', varid)
    CALL handle_err(istatus,'nf90_inq_varid T_SO not found')
    istatus =  nf90_get_var(ncid, varid, t_so)
    CALL handle_err(istatus,'nf90_get_var T_SO')

    istatus = nf90_inq_varid(ncid, 'W_SO_REL', varid)
    CALL handle_err(istatus,'nf90_inq_varid W_SO_REL not found')
    istatus =  nf90_get_var(ncid, varid, w_so_rel)
    CALL handle_err(istatus,'nf90_get_var W_SO_REL')
    w_so_rel(:,:,:,:) = w_so_rel(:,:,:,:) * 0.472

    istatus = nf90_inq_varid(ncid, 'FR_LAND', varid)
    CALL handle_err(istatus,'nf90_inq_varid FR_LAND  not found')
    istatus =  nf90_get_var(ncid, varid, fr_land(:,:,1,1))
    CALL handle_err(istatus,'nf90_get_var FR_LAND')
    fr_land(:,:,2,1) = fr_land(:,:,1,1)
    fr_land(:,:,3,1) = fr_land(:,:,1,1)
    fr_land(:,:,4,1) = fr_land(:,:,1,1)

!... compute SMIL
  !... read soil type file for ERA5
    INQUIRE(file=ifs_soil_type_file,exist=lexist)
    IF (.NOT. lexist) THEN
      PRINT *,'ERROR: ',TRIM(ifs_soil_type_file),' does not exist'
      STOP
    END IF
    istatus = nf90_open (TRIM(ifs_soil_type_file), NF90_NOWRITE, ncid_soil_type)
    CALL handle_err(istatus,'nf90_open '//TRIM(ifs_soil_type_file))

    istatus = nf90_inq_varid(ncid_soil_type, 'slt', varid)
    CALL handle_err(istatus,'nf90_inq_varid slt not found')
    istatus =  nf90_get_var(ncid_soil_type, varid, soil_type(:,:,1,1))
    CALL handle_err(istatus,'nf90_get_var slt')

    istatus=nf90_close(ncid_soil_type)
    CALL handle_err(istatus,'nf90_close '//TRIM(ifs_soil_type_file))

    soil_type(:,:,2,1) = soil_type(:,:,1,1)
    soil_type(:,:,3,1) = soil_type(:,:,1,1)
    soil_type(:,:,4,1) = soil_type(:,:,1,1)

     WHERE (fr_land < 0.5) 
       smil = undef
!       t_so = undef
     ELSE WHERE
      WHERE (soil_type == 1)
         smil = (w_so_rel-pwp(1))/(fc(1)-pwp(1))
      ELSE WHERE (soil_type == 2)
         smil = (w_so_rel-pwp(2))/(fc(2)-pwp(2))
      ELSE WHERE (soil_type == 3)
         smil = (w_so_rel-pwp(3))/(fc(3)-pwp(3))
      ELSE WHERE (soil_type == 4)
         smil = (w_so_rel-pwp(4))/(fc(4)-pwp(4))
      ELSE WHERE (soil_type == 5)
         smil = (w_so_rel-pwp(5))/(fc(5)-pwp(5))
      ELSE WHERE 
         smil = (w_so_rel-pwp(6))/(fc(6)-pwp(6))
      END WHERE
    END WHERE
 

    istatus = nf90_redef(ncid)
    CALL handle_err(istatus,'nf90_redef')
    istatus = nf90_def_dim(ncid, 'depth', 1, dp1id)
    CALL handle_err(istatus,'nf90_def_dim depth')
    istatus = nf90_def_dim(ncid, 'depth_2', 1, dp2id)
    CALL handle_err(istatus,'nf90_def_dim depth_2')
    istatus = nf90_def_dim(ncid, 'depth_3', 1, dp3id)
    CALL handle_err(istatus,'nf90_def_dim depth_3')
    istatus = nf90_def_dim(ncid, 'depth_4', 1, dp4id)
    CALL handle_err(istatus,'nf90_def_dim depth_4')
    
    istatus = nf90_def_var(ncid, 'depth', NF90_DOUBLE, dp1id, dp1varid)
    CALL handle_err(istatus,'nf90_def_var depth')
    istatus = nf90_def_var(ncid, 'depth_2', NF90_DOUBLE, dp2id, dp2varid)
    CALL handle_err(istatus,'nf90_def_var depth_2')
    istatus = nf90_def_var(ncid, 'depth_3', NF90_DOUBLE, dp3id, dp3varid)
    CALL handle_err(istatus,'nf90_def_var depth_3')
    istatus = nf90_def_var(ncid, 'depth_4', NF90_DOUBLE, dp4id, dp4varid)
    CALL handle_err(istatus,'nf90_def_var depth_4')
    
    istatus = nf90_enddef(ncid)
    CALL handle_err(istatus,'nf90_enddef')
    istatus =  nf90_put_var(ncid, dp1varid, soil_depth(1))
    CALL handle_err(istatus,'nf90_put_var depth')
    istatus =  nf90_put_var(ncid, dp2varid, soil_depth(2))
    CALL handle_err(istatus,'nf90_put_var depth_2')
    istatus =  nf90_put_var(ncid, dp3varid, soil_depth(3))
    CALL handle_err(istatus,'nf90_put_var depth_3')
    istatus =  nf90_put_var(ncid, dp4varid, soil_depth(4))
    CALL handle_err(istatus,'nf90_put_var depth_4')

    istatus = nf90_redef(ncid)
    CALL handle_err(istatus,'nf90_redef')
    istatus = nf90_def_var(ncid, 'STL1', NF90_FLOAT, (/ lonid, latid, dp1id, timeid /), stl1varid)
    CALL handle_err(istatus,'nf90_def_var STL1')
    istatus = nf90_put_att(ncid, stl1varid, "_FillValue", undef)
    CALL handle_err(istatus,'nf90_put_att STL1')
    istatus = nf90_def_var(ncid, 'STL2', NF90_FLOAT, (/ lonid, latid, dp2id, timeid /), stl2varid)
    CALL handle_err(istatus,'nf90_def_var STL2')
    istatus = nf90_put_att(ncid, stl2varid, "_FillValue", undef)
    CALL handle_err(istatus,'nf90_put_att STL2')
    istatus = nf90_def_var(ncid, 'STL3', NF90_FLOAT, (/ lonid, latid, dp3id, timeid /), stl3varid)
    CALL handle_err(istatus,'nf90_def_var STL3')
    istatus = nf90_put_att(ncid, stl3varid, "_FillValue", undef)
    CALL handle_err(istatus,'nf90_put_att STL3')
    istatus = nf90_def_var(ncid, 'STL4', NF90_FLOAT, (/ lonid, latid, dp4id, timeid /), stl4varid)
    CALL handle_err(istatus,'nf90_def_var STL4')
    istatus = nf90_put_att(ncid, stl4varid, "_FillValue", undef)
    CALL handle_err(istatus,'nf90_put_att STL4')

    istatus = nf90_enddef(ncid)
    CALL handle_err(istatus,'enddef')
    istatus =  nf90_put_var(ncid, stl1varid, t_so(:,:,1,1))
    CALL handle_err(istatus,'nf90_put_var STL1')
    istatus =  nf90_put_var(ncid, stl2varid, t_so(:,:,2,1))
    CALL handle_err(istatus,'nf90_put_var STL2')
    istatus =  nf90_put_var(ncid, stl3varid, t_so(:,:,3,1))
    CALL handle_err(istatus,'nf90_put_var STL3')
    istatus =  nf90_put_var(ncid, stl4varid, t_so(:,:,4,1))
    CALL handle_err(istatus,'nf90_put_var STL4')

    

    istatus = nf90_redef(ncid)
    CALL handle_err(istatus,'nf90_redef')
    istatus = nf90_def_var(ncid, 'SMIL1', NF90_FLOAT, (/ lonid, latid, dp1id, timeid /), smil1varid)
    CALL handle_err(istatus,'nf90_def_var SMIL1')
    istatus = nf90_put_att(ncid, smil1varid, "_FillValue", undef)
    CALL handle_err(istatus,'nf90_put_att SMIL1')
    istatus = nf90_def_var(ncid, 'SMIL2', NF90_FLOAT, (/ lonid, latid, dp2id, timeid /), smil2varid)
    CALL handle_err(istatus,'nf90_def_var SMIL2')
    istatus = nf90_put_att(ncid, smil2varid, "_FillValue", undef)
    CALL handle_err(istatus,'nf90_put_att SMIL2')
    istatus = nf90_def_var(ncid, 'SMIL3', NF90_FLOAT, (/ lonid, latid, dp3id, timeid /), smil3varid)
    CALL handle_err(istatus,'nf90_def_var SMIL3')
    istatus = nf90_put_att(ncid, smil3varid, "_FillValue", undef)
    CALL handle_err(istatus,'nf90_put_att SMIL3')
    istatus = nf90_def_var(ncid, 'SMIL4', NF90_FLOAT, (/ lonid, latid, dp4id, timeid /), smil4varid)
    CALL handle_err(istatus,'nf90_def_var SMIL4')
    istatus = nf90_put_att(ncid, smil4varid, "_FillValue", undef)
    CALL handle_err(istatus,'nf90_put_att SMIL4')

    istatus = nf90_enddef(ncid)
    CALL handle_err(istatus,'nf90_enddef')
    istatus =  nf90_put_var(ncid, smil1varid, smil(:,:,1,1))
    CALL handle_err(istatus,'nf90_put_var SMIL1')
    istatus =  nf90_put_var(ncid, smil2varid, smil(:,:,2,1))
    CALL handle_err(istatus,'nf90_put_var SMIL2')
    istatus =  nf90_put_var(ncid, smil3varid, smil(:,:,3,1))
    CALL handle_err(istatus,'nf90_put_var SMIL3')
    istatus =  nf90_put_var(ncid, smil4varid, smil(:,:,4,1))
    CALL handle_err(istatus,'nf90_put_var SMIL4')

    
    DEALLOCATE (t_so, w_so_rel, soil_type, smil)

END SUBROUTINE create_era5_soil_quantities

!=============================================================================


SUBROUTINE create_default_soil_quantities (ncid, lonid, latid, timeid, nlon, nlat, ntime)

! Description:
!   Create default soil quantities SLTn and SMIn

  INTEGER :: &
    ncid, lonid, latid, timeid, nlon, nlat, ntime
    
    
  REAL, ALLOCATABLE :: &
    smil(:,:,:), &
    ts(:,:,:), &
    stl(:,:,:), &
    fr_land(:,:,:)

  REAL :: &
    rsmi
    
  INTEGER :: &
    istatus, varid, dp1d, dp2d, dp3d, dp4d, &
    dp1id, dp2id, dp3id, dp4id, &
    dp1varid, dp2varid, dp3varid, dp4varid, &
    smil1varid, smil2varid, smil3varid, smil4varid, &
    stl1varid, stl2varid, stl3varid, stl4varid
    
  CHARACTER (LEN=50) :: &
    csmi

    ALLOCATE (smil(nlon, nlat, 1), ts(nlon, nlat, 1), stl(nlon, nlat, 1), fr_land(nlon, nlat, 1))

    istatus = nf90_inq_varid(ncid, 'FR_LAND', varid)
    CALL handle_err(istatus,'nf90_inq_varid FR_LAND  not found')
    istatus =  nf90_get_var(ncid, varid, fr_land(:,:,1))
    CALL handle_err(istatus,'nf90_get_var FR_LAND')

!... set environment variable SMI_DEFAULT in your scripts. Do not forget to export it (e.g. "export SMI_DEFAULT=0.5")
     CALL get_environment_variable ("SMI_DEFAULT", csmi, status=istatus)
     IF (istatus == 0) THEN
       READ(csmi,*) rsmi
     ELSE
       rsmi = 1.
     ENDIF

    istatus = nf90_redef(ncid)
    CALL handle_err(istatus,'nf90_redef')
    istatus = nf90_def_dim(ncid, 'depth', 1, dp1id)
    CALL handle_err(istatus,'nf90_def_dim depth')
    istatus = nf90_def_dim(ncid, 'depth_2', 1, dp2id)
    CALL handle_err(istatus,'nf90_def_dim depth_2')
    istatus = nf90_def_dim(ncid, 'depth_3', 1, dp3id)
    CALL handle_err(istatus,'nf90_def_dim depth_3')
    istatus = nf90_def_dim(ncid, 'depth_4', 1, dp4id)
    CALL handle_err(istatus,'nf90_def_dim depth_4')
    
    istatus = nf90_def_var(ncid, 'depth', NF90_DOUBLE, dp1id, dp1varid)
    CALL handle_err(istatus,'nf90_def_var depth')
    istatus = nf90_def_var(ncid, 'depth_2', NF90_DOUBLE, dp2id, dp2varid)
    CALL handle_err(istatus,'nf90_def_var depth_2')
    istatus = nf90_def_var(ncid, 'depth_3', NF90_DOUBLE, dp3id, dp3varid)
    CALL handle_err(istatus,'nf90_def_var depth_3')
    istatus = nf90_def_var(ncid, 'depth_4', NF90_DOUBLE, dp4id, dp4varid)
    CALL handle_err(istatus,'nf90_def_var depth_4')
    
    istatus = nf90_enddef(ncid)
    CALL handle_err(istatus,'nf90_enddef')
    istatus =  nf90_put_var(ncid, dp1varid, default_soil_depth(1))
    CALL handle_err(istatus,'nf90_put_var depth')
    istatus =  nf90_put_var(ncid, dp2varid, default_soil_depth(2))
    CALL handle_err(istatus,'nf90_put_var depth_2')
    istatus =  nf90_put_var(ncid, dp3varid, default_soil_depth(3))
    CALL handle_err(istatus,'nf90_put_var depth_3')
    istatus =  nf90_put_var(ncid, dp4varid, default_soil_depth(4))
    CALL handle_err(istatus,'nf90_put_var depth_4')


    istatus = nf90_inq_varid(ncid, 'T_SKIN', varid)
    IF (istatus == NF90_NOERR) THEN
      istatus =  nf90_get_var(ncid, varid, ts)
    ELSE
      istatus = nf90_inq_varid(ncid, 'T_S', varid)
      IF (istatus == NF90_NOERR) THEN
        istatus =  nf90_get_var(ncid, varid, ts)
      ELSE
        PRINT *, 'ERROR: neither T_SKIN nor T_S found'
        STOP
      ENDIF
    ENDIF

     WHERE (fr_land < 0.5) 
       smil = undef
!       ts   = undef
     ELSE WHERE
       smil = rsmi
     END WHERE

    istatus = nf90_redef(ncid)
    CALL handle_err(istatus,'nf90_redef')
    istatus = nf90_def_var(ncid, 'STL1', NF90_FLOAT, (/ lonid, latid, dp1id, timeid /), stl1varid)
    CALL handle_err(istatus,'nf90_def_var STL1')
    istatus = nf90_put_att(ncid, stl1varid, "_FillValue", undef)
    CALL handle_err(istatus,'nf90_put_att STL1')
    istatus = nf90_def_var(ncid, 'STL2', NF90_FLOAT, (/ lonid, latid, dp2id, timeid /), stl2varid)
    CALL handle_err(istatus,'nf90_def_var STL2')
    istatus = nf90_put_att(ncid, stl2varid, "_FillValue", undef)
    CALL handle_err(istatus,'nf90_put_att STL2')
    istatus = nf90_def_var(ncid, 'STL3', NF90_FLOAT, (/ lonid, latid, dp3id, timeid /), stl3varid)
    CALL handle_err(istatus,'nf90_def_var STL3')
    istatus = nf90_put_att(ncid, stl3varid, "_FillValue", undef)
    CALL handle_err(istatus,'nf90_put_att STL3')
    istatus = nf90_def_var(ncid, 'STL4', NF90_FLOAT, (/ lonid, latid, dp4id, timeid /), stl4varid)
    CALL handle_err(istatus,'nf90_def_var STL4')
    istatus = nf90_put_att(ncid, stl4varid, "_FillValue", undef)
    CALL handle_err(istatus,'nf90_put_att STL4')

    istatus = nf90_enddef(ncid)
    CALL handle_err(istatus,'nf90_enddef')
    WHERE (ts /= undef) stl = ts + (283.15 - ts) /10. * default_soil_depth(1)
    istatus =  nf90_put_var(ncid, stl1varid, stl)    
    CALL handle_err(istatus,'nf90_put_var STL1')
    WHERE (ts /= undef) stl = ts + (283.15 - ts) /10. * default_soil_depth(2)
    istatus =  nf90_put_var(ncid, stl2varid, stl)    
    CALL handle_err(istatus,'nf90_put_var STL2')
    WHERE (ts /= undef) stl = ts + (283.15 - ts) /10. * default_soil_depth(3)
    istatus =  nf90_put_var(ncid, stl3varid, stl)    
    CALL handle_err(istatus,'nf90_put_var STL3')
    WHERE (ts /= undef) stl = ts + (283.15 - ts) /10. * default_soil_depth(4)
    istatus =  nf90_put_var(ncid, stl4varid, stl)    
    CALL handle_err(istatus,'nf90_put_var STL4')

    istatus = nf90_redef(ncid)
    CALL handle_err(istatus,'nf90_redef')
    istatus = nf90_def_var(ncid, 'SMIL1', NF90_FLOAT, (/ lonid, latid, dp1id, timeid /), smil1varid)
    CALL handle_err(istatus,'nf90_def_var SMIL1')
    istatus = nf90_put_att(ncid, smil1varid, "_FillValue", undef)
    CALL handle_err(istatus,'nf90_put_att SMIL1')
    istatus = nf90_def_var(ncid, 'SMIL2', NF90_FLOAT, (/ lonid, latid, dp2id, timeid /), smil2varid)
    CALL handle_err(istatus,'nf90_def_var SMIL2')
    istatus = nf90_put_att(ncid, smil2varid, "_FillValue", undef)
    CALL handle_err(istatus,'nf90_put_att SMIL2')
    istatus = nf90_def_var(ncid, 'SMIL3', NF90_FLOAT, (/ lonid, latid, dp3id, timeid /), smil3varid)
    CALL handle_err(istatus,'nf90_def_var SMIL3')
    istatus = nf90_put_att(ncid, smil3varid, "_FillValue", undef)
    CALL handle_err(istatus,'nf90_put_att SMIL3')
    istatus = nf90_def_var(ncid, 'SMIL4', NF90_FLOAT, (/ lonid, latid, dp4id, timeid /), smil4varid)
    CALL handle_err(istatus,'nf90_def_var SMIL4')
    istatus = nf90_put_att(ncid, smil4varid, "_FillValue", undef)
    CALL handle_err(istatus,'nf90_put_att SMIL4')

    istatus = nf90_enddef(ncid)
    CALL handle_err(istatus,'nf90_enddef')
    istatus =  nf90_put_var(ncid, smil1varid, smil)
    CALL handle_err(istatus,'nf90_put_var SMIL1')
    istatus =  nf90_put_var(ncid, smil2varid, smil)
    CALL handle_err(istatus,'nf90_put_var SMIL2')
    istatus =  nf90_put_var(ncid, smil3varid, smil)
    CALL handle_err(istatus,'nf90_put_var SMIL3')
    istatus =  nf90_put_var(ncid, smil4varid, smil)
    CALL handle_err(istatus,'nf90_put_var SMIL4')

    
    DEALLOCATE (smil, ts, stl)

END SUBROUTINE create_default_soil_quantities

!=============================================================================
END MODULE mo_c2i_soil


