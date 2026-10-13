SUBROUTINE icon_domain (ncfile, nbound, nudge_zone_width, Rn, Bk)

!-------------------------------------------------------------------------------
!
! Description:
!   Get input for creating icon grid and extpar files with the 
!      ICON Grid Generator + ExtPar Web Frontend 
!
!   Usage:
!     icon_domain <ncfile> <nbound> <nudge_zone_width> <Rn> <Bk>
!
!    Meaning 1. Option
!    ncfile: file holding the rotated grid information on which the output of ICON will be interpolated
!    nbound: add sponge zone, i.e. number of extra boundary pixels (are the same on all sides)
!
!    Meaning 2. Option
!    ncfile: file holding the rotated grid information on which the output of ICON will be interpolated
!    nbound: extra boundary pixels (are the same on all sides), for safety reason!
!    nudge_zone_width: same as will be used in the planed ICON simulations
!    Rn: definition of ICON grid
!    Bk: definition of ICON grid
!
!   The result is written to standard output
!
!.....................................................
! Copyright 2021 Helmholtz-Zentrum Hereon
! Licensed under the GNU License, Version 3.0
! (https://www.gnu.org/licenses/gpl-3.0.html)
! Author(s): Burkhardt Rockel (Hereon)
!.....................................................
!
!-------------------------------------------------------------------------------
!

  USE netcdf
  
  IMPLICIT NONE


! Input Parameter list:
! ---------------------

  CHARACTER (LEN=*) :: &
    ncfile       ! file holding the rotated grid information on which the output of ICON will be interpolated
  INTEGER :: &
    nbound,             &  ! number of extra boundary pixels (are the same on all sides)
    nudge_zone_width,   &  ! add sponge zone, i.e. number of extra boundary pixels (are the same on all sides)
    Rn,                 &  ! definition of ICON grid
    Bk                     ! definition of ICON grid

! Local variables:
! ------------------------------------

  INTEGER, PARAMETER :: &
      grf_bdywidth_c=4


  INTEGER :: &
    ncid,      &  ! ncfile ID
    rotvarid,  &  ! rotated pole varID
    rlonvarid, &
    rlatvarid, &
    rlondimid, &
    rlatdimid, &
    nrlon,     &
    nrlat,     &
    extend_rotated_x, &
    extend_rotated_y, &
    istatus         ! status variable

  REAL, ALLOCATABLE :: &
    rlon(:),     &
    rlat(:)

  REAL :: &
    pollon, &
    pollat, &
    polgam

  REAL :: &
    rlonbound,   &
    rlatbound,   &
    half_width,  &
    half_height, &
    centerlon,   &
    centerlat

  REAL  :: &
    dx_icon,   &
    dx_rot,    &
    dy_rot

!- End of header
!------------------------------------------------------------------------------

  ! open the data file
  istatus = nf90_open(TRIM(ncfile), NF90_NOWRITE, ncid)
  IF (istatus /= NF90_NOERR) THEN
    STOP
  ENDIF

!... read rotated pole
  istatus = nf90_inq_varid(ncid, 'rotated_pole', rotvarid)
  IF (istatus /= NF90_NOERR) THEN
    PRINT *, '*** ERROR: rotated_pole not found'
    STOP
  ENDIF
  istatus = nf90_get_att (ncid, rotvarid, 'grid_north_pole_longitude', pollon)
  IF (istatus /= NF90_NOERR) THEN
    PRINT *, '*** ERROR: rotated_pole attribute grid_north_pole_longitude not found'
    STOP
  ENDIF
  istatus = nf90_get_att (ncid, rotvarid, 'grid_north_pole_latitude', pollat)
  IF (istatus /= NF90_NOERR) THEN
    PRINT *, '*** ERROR: rotated_pole attribute grid_north_pole_latitude not found'
    STOP
  ENDIF
  istatus = nf90_get_att (ncid, rotvarid, 'north_pole_grid_longitude', polgam)
  IF (istatus /= NF90_NOERR) THEN
    polgam = 0.
  ENDIF

!... read rlon and rlat
  istatus = nf90_inq_varid(ncid, 'rlon', rlonvarid)
  IF (istatus /= NF90_NOERR) THEN
    PRINT *, '*** ERROR: rlon nf90_inq_varid'
    STOP
  ENDIF
  istatus = nf90_inq_dimid(ncid, "rlon", rlondimid)
  IF (istatus /= NF90_NOERR) THEN
    PRINT *, '*** ERROR: rlon nf90_inq_dimid'
    STOP
  ENDIF
  istatus = nf90_inquire_dimension(ncid, rlondimid, len = nrlon)
  IF (istatus /= NF90_NOERR) THEN
    PRINT *, '*** ERROR: rlon nf90_inquire_dimension'
    STOP
  ENDIF

  istatus = nf90_inq_varid(ncid, 'rlat', rlatvarid)
  IF (istatus /= NF90_NOERR) THEN
    PRINT *, '*** ERROR: rlat nf90_inq_varid'
    STOP
  ENDIF
  istatus = nf90_inq_dimid(ncid, "rlat", rlatdimid)
  IF (istatus /= NF90_NOERR) THEN
    PRINT *, '*** ERROR: rlat nf90_inq_dimid'
    STOP
  ENDIF
  istatus = nf90_inquire_dimension(ncid, rlatdimid, len = nrlat)
  IF (istatus /= NF90_NOERR) THEN
    PRINT *, '*** ERROR: rlat nf90_inquire_dimension'
    STOP
  ENDIF
  ALLOCATE (rlon(nrlon), rlat(nrlat))

 istatus = nf90_get_var(ncid, rlonvarid, rlon)
  IF (istatus /= NF90_NOERR) THEN
    PRINT *, '*** ERROR: rlon nf90_get_var'
    STOP
  ENDIF
 istatus = nf90_get_var(ncid, rlatvarid, rlat)
  IF (istatus /= NF90_NOERR) THEN
    PRINT *, '*** ERROR: rlat nf90_get_var'
    STOP
  ENDIF

  extend_rotated_x = nbound
  extend_rotated_y = nbound
  IF ((nudge_zone_width + Rn + Bk) /= 0) THEN
    dx_icon = 5050 / (Rn * 2**Bk)
    dx_rot  = (rlon(2) - rlon(1))*111.111
    dy_rot  = (rlat(2) - rlat(1))*111.111
    extend_rotated_x = extend_rotated_x + nudge_zone_width + grf_bdywidth_c
    extend_rotated_y = extend_rotated_y + nudge_zone_width + grf_bdywidth_c
    IF (dx_rot < dx_icon) then
      extend_rotated_x = ceiling((dx_icon - dx_rot)*nrlon / dx_rot) + extend_rotated_x
    ENDIF
    IF (dy_rot < dx_icon) then
      extend_rotated_y = ceiling((dx_icon - dy_rot)*nrlat / dy_rot) + extend_rotated_y
    ENDIF
  ENDIF

!   write(*,*) 'extend_rotated_x = ',extend_rotated_x
!   write(*,*) 'extend_rotated_y = ',extend_rotated_y
   
!  half_width  = (REAL(ie_tot-1)*dlon)/2.
!  half_height = (REAL(je_tot-1)*dlat)/2.
  rlonbound = (rlon(2) - rlon(1)) * extend_rotated_x
  rlatbound = (rlat(2) - rlat(1)) * extend_rotated_y
  half_width  = ((rlon(nrlon)-rlon(1)) + 2.*rlonbound)/2.
  half_height = ((rlat(nrlat)-rlat(1)) + 2.*rlatbound)/2.
  centerlon   = rlon(1) - rlonbound + half_width - polgam
  centerlat   = rlat(1) - rlatbound + half_height


  WRITE(*,*) 'write parent grid: (tick box)'
  WRITE(*,'(A,F10.5)') 'center: longitude (degrees) ', centerlon
  WRITE(*,'(A,F10.5)') 'center: latitude (degrees)  ', centerlat
  WRITE(*,'(A,F10.5)') 'half width:  ',half_width
  WRITE(*,'(A,F10.5)') 'half height: ',half_height
  WRITE(*,*) 'rotate: (tick box) ' 
  WRITE(*,'(A,F10.5,A,F10.5)') 'north pole: longitude (degrees) ', pollon, '   latitude (degrees) ', pollat
  
  DEALLOCATE (rlon, rlat)
  istatus = nf90_close(ncid)



END SUBROUTINE icon_domain
