SUBROUTINE add_lonlat (ncfile)

!-------------------------------------------------------------------------------
!
! Description:
!   This program adds 2D geographical latitude and longitude to a netCDF file
!     containing rotated coordinats
!
!   Usage:
!     add_lonlat <ncfile>
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
  USE mo_kind
  USE mo_utilities

  IMPLICIT NONE

! Input Parameter list:
! ---------------------

  CHARACTER (LEN=*) :: ncfile

! Local variables:
! ------------------------------------

  REAL (KIND=wp) :: pollon, pollat, polgam

  CHARACTER (LEN=80) :: &
    grid_name        ! name of grid mapping

  INTEGER :: i, j, istatus
  INTEGER :: ncid
  INTEGER :: varid_rlon, varid_rlat, dimid_rlon, dimid_rlat
  INTEGER :: varid_lon, varid_lat, varid_rotated_pole
  INTEGER :: nlon, nlat

  REAL (KIND=wp), ALLOCATABLE :: &
    rlon(:), &
    rlat(:)

  REAL (KIND=wp), ALLOCATABLE :: &
    lon(:,:), &
    lat(:,:)

!------------ End of header ----------------------------------------------------


  ! get file ID
  istatus = nf90_open (ncfile, NF90_WRITE, ncid)
  IF (istatus /= NF90_NOERR) THEN
    PRINT *, 'Error in nf90_open' 
    PRINT *, TRIM(NF90_strerror(istatus))
    STOP
  ENDIF


  istatus = nf90_inq_varid(ncid, 'rotated_pole', varid_rotated_pole)
  IF (istatus == NF90_NOERR) THEN   ! rotated latitude-longitude
    istatus = nf90_get_att(ncid, varid_rotated_pole, 'grid_mapping_name', grid_name)
    IF (istatus /= NF90_NOERR) THEN
      PRINT *, 'Error in read_nc_gdefs / nf90_get_att'
      PRINT *, 'Attribute "grid_mapping_name"'
      PRINT *, TRIM(NF90_strerror(istatus))
    ENDIF
    IF (grid_name(1:26) /= 'rotated_latitude_longitude') THEN
      PRINT *, 'Error in read_nc_gdefs'
      PRINT *, 'Invalid value for attribute "grid_mapping_name"'
      PRINT *, TRIM(grid_name)
    ENDIF
    istatus = nf90_get_att(ncid, varid_rotated_pole, 'grid_north_pole_latitude', pollat)
    IF (istatus /= NF90_NOERR) THEN
      PRINT *, 'Error in read_nc_gdefs / nf90_get_att'
      PRINT *, 'Attribute "grid_north_pole_latitude"'
      PRINT *, TRIM(NF90_strerror(istatus))
      RETURN
    ENDIF
    istatus = nf90_get_att(ncid, varid_rotated_pole, 'grid_north_pole_longitude', pollon)
    IF (istatus /= NF90_NOERR) THEN
      PRINT *, 'Error in read_nc_gdefs / nf90_get_att'
      PRINT *, 'Attribute "grid_north_pole_longitude"'
      PRINT *, TRIM(NF90_strerror(istatus))
      RETURN
    ENDIF
    istatus = nf90_get_att(ncid, varid_rotated_pole, 'north_pole_grid_longitude', polgam)
    IF (istatus == NF90_ENOTATT) THEN
      polgam = 0.
    ELSE IF (istatus /= NF90_NOERR) THEN
      PRINT *, 'Error in read_nc_gdefs / nf90_get_att'
      PRINT *, 'Attribute "north_pole_grid_longitude"'
      PRINT *, TRIM(NF90_strerror(istatus))
      RETURN
    ENDIF
  ELSE IF (istatus == NF90_ENOTVAR) THEN  ! true latitude-longitude
    pollon = 0.
    pollat = 90.
    polgam = 0.
  ELSE
     PRINT *, 'Error in read_nc_gdefs / nf90_inq_varid'
     PRINT *, 'Variable "rotated_pole"'
     RETURN
  ENDIF

    istatus = nf90_inq_varid(ncid, 'rlon', varid_rlon)
    IF (istatus /= NF90_NOERR) THEN
      PRINT *, 'Error in nccd_get / nf90_inq_varid' 
      PRINT *, TRIM(NF90_strerror(istatus))
      PRINT *, 'rlon'
      STOP
    ENDIF

  istatus = nf90_inq_dimid(ncid, 'rlon', dimid_rlon)
  IF (istatus /= NF90_NOERR) THEN
      PRINT 'Error in rlon / nf90_inq_dimid -- '// &
                TRIM(NF90_strerror(istatus))
      STOP
  ENDIF

  istatus = nf90_inquire_dimension(ncid, dimid_rlon, len=nlon)
  IF (istatus /= NF90_NOERR) THEN
      PRINT *, 'Error in rlon / nf90_inquire_dimension -- '// &
                TRIM(NF90_strerror(istatus))
      STOP
  ENDIF
  
  istatus = nf90_inq_varid(ncid, 'rlat', varid_rlat)
  IF (istatus /= NF90_NOERR) THEN
    PRINT *, 'Error in nccd_get / nf90_inq_varid' 
    PRINT *, TRIM(NF90_strerror(istatus))
    PRINT *, 'rlat'
    STOP
  ENDIF

  istatus = nf90_inq_dimid(ncid, 'rlat', dimid_rlat)
  IF (istatus /= NF90_NOERR) THEN
      PRINT *, 'Error in rlat / nf90_inq_dimid -- '// &
                TRIM(NF90_strerror(istatus))
      STOP
  ENDIF
 
  istatus = nf90_inquire_dimension(ncid, dimid_rlat, len=nlat)
  IF (istatus /= NF90_NOERR) THEN
     PRINT *, 'Error in rlon / nf90_inquire_dimension -- '// &
                TRIM(NF90_strerror(istatus))
      STOP
  ENDIF

  ALLOCATE (rlon(nlon))
  ALLOCATE (rlat(nlat))
  ALLOCATE (lon(nlon, nlat))
  ALLOCATE (lat(nlon, nlat))

! read the data values
  istatus = nf90_get_var (ncid, varid_rlon, rlon)
  IF (istatus /= NF90_NOERR) THEN
    PRINT *, 'Error in rlon nf90_get_var' 
    PRINT *, TRIM(NF90_strerror(istatus))
    STOP
  ENDIF

  istatus = nf90_get_var (ncid, varid_rlat, rlat)
  IF (istatus /= NF90_NOERR) THEN
    PRINT *, 'Error in rlon nf90_get_var' 
    PRINT *, TRIM(NF90_strerror(istatus))
    STOP
  ENDIF

  istatus = nf90_redef(ncid)

! geographic longitude
    istatus=nf90_def_var(ncid, "lon", NF90_FLOAT, (/ dimid_rlon, dimid_rlat /), varid_lon)
    IF (istatus /= NF90_NOERR) THEN
      PRINT *,TRIM(NF90_strerror(istatus))
      STOP
    ENDIF

    istatus=nf90_put_att(ncid, varid_lon, "standard_name", "longitude")
    IF (istatus /= NF90_NOERR) THEN
      PRINT *,TRIM(NF90_strerror(istatus))
      STOP
    ENDIF
    istatus=nf90_put_att(ncid, varid_lon, "long_name", "longitude")
    IF (istatus /= NF90_NOERR) THEN
      PRINT *,TRIM(NF90_strerror(istatus))
      STOP
    ENDIF
    istatus=nf90_put_att(ncid, varid_lon, "units", "degrees_east")
    IF (istatus /= NF90_NOERR) THEN
      PRINT *,TRIM(NF90_strerror(istatus))
      STOP
    ENDIF

  ! geographic latitude
    istatus=nf90_def_var(ncid, "lat", NF90_FLOAT, (/ dimid_rlon, dimid_rlat /), varid_lat)
    IF (istatus /= NF90_NOERR) THEN
      PRINT *,TRIM(NF90_strerror(istatus))
      STOP
    ENDIF
    istatus=nf90_put_att(ncid, varid_lat, "standard_name", "latitude")
    IF (istatus /= NF90_NOERR) THEN
      PRINT *,TRIM(NF90_strerror(istatus))
      STOP
    ENDIF
    istatus=nf90_put_att(ncid, varid_lat, "long_name", "latitude")
    IF (istatus /= NF90_NOERR) THEN
      PRINT *,TRIM(NF90_strerror(istatus))
      STOP
    ENDIF
   istatus=nf90_put_att(ncid, varid_lat, "units", "degrees_north")
    IF (istatus /= NF90_NOERR) THEN
      PRINT *,TRIM(NF90_strerror(istatus))
      STOP
    ENDIF
  

  istatus = nf90_enddef(ncid)
  
    DO j = 1, nlat
      DO i = 1, nlon
        CALL rot2geo (rlat(j), rlon(i), pollat, pollon, polgam, lat(i,j), lon(i,j))
      ENDDO
    ENDDO
  

  istatus = nf90_put_var (ncid, varid_lon, lon)
  IF (istatus /= NF90_NOERR) THEN
    PRINT *,TRIM(NF90_strerror(istatus)) // 'in put_var lon'
    STOP
  ENDIF
  istatus = nf90_put_var (ncid, varid_lat, lat)
  IF (istatus /= NF90_NOERR) THEN
    PRINT *,TRIM(NF90_strerror(istatus)) // 'in put_var lat'
    STOP
  ENDIF


  istatus = nf90_close(ncid)
   IF (istatus /= NF90_NOERR) THEN
    PRINT *,TRIM(NF90_strerror(istatus))
    STOP
  ENDIF

 
END SUBROUTINE add_lonlat


