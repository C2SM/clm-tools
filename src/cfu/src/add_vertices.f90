SUBROUTINE add_vertices (ncfile)

!-------------------------------------------------------------------------------
!
! Description:
!   This program adds latitude and longitude vertices to a netCDF file
!   works only for rotated and geographical coordinates
!
!   Usage:
!     add_vertices <ncfile>
!
!   Order of the vertices
!     4 ---- 3
!     |      |
!     1 ---- 2
!
!.....................................................
! Copyright 2021 Helmholtz-Zentrum Hereon
! Copyright 2019-2020 Helmholtz-Zentrum Geesthacht
! Licensed under the GNU License, Version 3.0
! (https://www.gnu.org/licenses/gpl-3.0.html)
! Author(s): Burkhardt Rockel (Hereon), Klaus Keuler (BTU Cottbus)
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

  INTEGER :: i, j, k, istatus
  INTEGER :: ncid
  INTEGER :: varid_plon, varid_plat, dimid_plon, dimid_plat
  INTEGER :: dimid_vertices
  INTEGER :: varid_lon, varid_lat, varid_rotated_pole
  INTEGER :: varid_lon_vertices, varid_lat_vertices
  INTEGER :: nlon, nlat
  INTEGER :: itype_grid
  
  REAL (KIND=wp) , ALLOCATABLE :: &
    plon(:), &
    plat(:)

  REAL (KIND=wp) , ALLOCATABLE :: &
    lon_vertices(:,:,:), &
    lat_vertices(:,:,:) 
    
  REAL (KIND=wp) :: &
    plat_vertex1, plat_vertex2, plon_vertex1, plon_vertex2
    

!------------ End of header ----------------------------------------------------


  ! get file ID
  istatus = nf90_open (ncfile, NF90_WRITE, ncid)
  IF (istatus /= NF90_NOERR) THEN
    PRINT *, 'Error in nf90_open' 
    PRINT *, TRIM(NF90_strerror(istatus))
    STOP
  ENDIF

  itype_grid = 0

!... check whether the coordinate system is rotated grid or not

  istatus = nf90_inq_varid(ncid, 'rotated_pole', varid_rotated_pole)
  IF (istatus == NF90_NOERR) THEN   ! rotated latitude-longitude
    itype_grid = 2
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
    itype_grid = 1
    pollon = 0.
    pollat = 90.
    polgam = 0.
  ELSE
     PRINT *, 'Error in read_nc_gdefs / nf90_inq_varid'
     PRINT *, 'Variable "rotated_pole"'
     RETURN
  ENDIF


!.................................................................
!... Geographical grid (no rotated grid)
  IF (itype_grid == 1) THEN

    istatus = nf90_inq_varid(ncid, 'lon', varid_plon)
    IF (istatus /= NF90_NOERR) THEN
      PRINT *, 'Error in nccd_get / nf90_inq_varid' 
      PRINT *, TRIM(NF90_strerror(istatus))
      PRINT *, 'lon'
      STOP
    ENDIF

  istatus = nf90_inq_dimid(ncid, 'lon', dimid_plon)
  IF (istatus /= NF90_NOERR) THEN
      PRINT *, 'Error in plat / nf90_inq_dimid -- '// &
                TRIM(NF90_strerror(istatus))
      STOP
  ENDIF
 

  istatus = nf90_inquire_dimension(ncid, dimid_plon, len=nlon)
  IF (istatus /= NF90_NOERR) THEN
      PRINT *, 'Error in plon / nf90_inquire_dimension -- '// &
                TRIM(NF90_strerror(istatus))
      STOP
  ENDIF
  
  istatus = nf90_inq_varid(ncid, 'lat', varid_plat)
  IF (istatus /= NF90_NOERR) THEN
    PRINT *, 'Error in nccd_get / nf90_inq_varid' 
    PRINT *, TRIM(NF90_strerror(istatus))
    PRINT *, 'lat'
    STOP
  ENDIF

  istatus = nf90_inq_dimid(ncid, 'lat', dimid_plat)
  IF (istatus /= NF90_NOERR) THEN
      PRINT *, 'Error in plat / nf90_inq_dimid -- '// &
                TRIM(NF90_strerror(istatus))
      STOP
  ENDIF
 
  istatus = nf90_inquire_dimension(ncid, dimid_plat, len=nlat)
  IF (istatus /= NF90_NOERR) THEN
     PRINT *, 'Error in plon / nf90_inquire_dimension -- '// &
                TRIM(NF90_strerror(istatus))
      STOP
  ENDIF

  ALLOCATE (plon(nlon))
  ALLOCATE (plat(nlat))
  ALLOCATE (lon_vertices(4, nlon, nlat))
  ALLOCATE (lat_vertices(4, nlon, nlat))

! read the data values
  istatus = nf90_get_var (ncid, varid_plon, plon)
  IF (istatus /= NF90_NOERR) THEN
    PRINT *, 'Error in plon nf90_get_var' 
    PRINT *, TRIM(NF90_strerror(istatus))
    STOP
  ENDIF

  istatus = nf90_get_var (ncid, varid_plat, plat)
  IF (istatus /= NF90_NOERR) THEN
    PRINT *, 'Error in plon nf90_get_var' 
    PRINT *, TRIM(NF90_strerror(istatus))
    STOP
  ENDIF

  istatus = nf90_redef(ncid)

  istatus=nf90_def_dim(ncid,"nv", 4, dimid_vertices)
  IF (istatus /= NF90_NOERR) THEN
    PRINT *, 'Error in nf90_def_dim of vertices'
    PRINT *, TRIM(NF90_strerror(istatus))
    RETURN
  ENDIF

! geographic longitude
  istatus=nf90_def_var(ncid, "lon_bnds", NF90_FLOAT, (/ dimid_vertices, dimid_plon, dimid_plat  /), varid_lon_vertices)
  IF (istatus /= NF90_NOERR) THEN
    PRINT *,TRIM(NF90_strerror(istatus))
    STOP
  ENDIF

  istatus=nf90_put_att(ncid, varid_lon_vertices, "units", "degrees_east")
  IF (istatus /= NF90_NOERR) THEN
    PRINT *,TRIM(NF90_strerror(istatus))
    STOP
  ENDIF

  ! geographic latitude
  istatus=nf90_def_var(ncid, "lat_bnds", NF90_FLOAT, (/ dimid_vertices, dimid_plon, dimid_plat /), varid_lat_vertices)
  IF (istatus /= NF90_NOERR) THEN
    PRINT *,TRIM(NF90_strerror(istatus))
    STOP
  ENDIF
  istatus=nf90_put_att(ncid, varid_lat_vertices, "units", "degrees_north")
  IF (istatus /= NF90_NOERR) THEN
    PRINT *,TRIM(NF90_strerror(istatus))
    STOP
  ENDIF


  ! add attribute "bounds" to lon and lat
  istatus=nf90_put_att(ncid, varid_plon, "bounds", "lon_bnds")
  IF (istatus /= NF90_NOERR) THEN
    PRINT *,TRIM(NF90_strerror(istatus))
    STOP
  ENDIF

  istatus=nf90_put_att(ncid, varid_plat, "bounds", "lat_bnds")
  IF (istatus /= NF90_NOERR) THEN
    PRINT *,TRIM(NF90_strerror(istatus))
    STOP
  ENDIF


  istatus = nf90_enddef(ncid)
  
!... calculate vertices
  DO j = 2, nlat-1
    DO i = 2, nlon-1
      plat_vertex1 = (plat(j+1) + plat(j)) / 2.
      plat_vertex2 = (plat(j-1) + plat(j)) / 2.
      plon_vertex1 = (plon(i-1) + plon(i)) / 2.
      plon_vertex2 = (plon(i+1) + plon(i)) / 2.
      lon_vertices(1,i,j) = plon_vertex1
      lat_vertices(1,i,j) = plat_vertex2
      lon_vertices(2,i,j) = plon_vertex2
      lat_vertices(2,i,j) = plat_vertex2
      lon_vertices(3,i,j) = plon_vertex2
      lat_vertices(3,i,j) = plat_vertex1
      lon_vertices(4,i,j) = plon_vertex1
      lat_vertices(4,i,j) = plat_vertex1
    ENDDO
  ENDDO

!... northern edge and southern edge
  DO i = 2, nlon -1
      plat_vertex1 = (plat(2) + plat(1)) / 2.
      plat_vertex2 = plat(1) + (plat(1) - plat(2)) / 2.
      plon_vertex1 = (plon(i-1) + plon(i)) / 2.
      plon_vertex2 = (plon(i+1) + plon(i)) / 2.
      lon_vertices(1,i,1) = plon_vertex1
      lat_vertices(1,i,1) = plat_vertex2
      lon_vertices(2,i,1) = plon_vertex2
      lat_vertices(2,i,1) = plat_vertex2
      lon_vertices(3,i,1) = plon_vertex2
      lat_vertices(3,i,1) = plat_vertex1   
      lon_vertices(4,i,1) = plon_vertex1
      lat_vertices(4,i,1) = plat_vertex1
      plat_vertex1 = plat(nlat) - (plat(nlat-1) - plat(nlat)) / 2.
      plat_vertex2 = (plat(nlat-1) + plat(nlat)) / 2.
      lon_vertices(1,i,nlat) = plon_vertex1
      lat_vertices(1,i,nlat) = plat_vertex2
      lon_vertices(2,i,nlat) = plon_vertex2
      lat_vertices(2,i,nlat) = plat_vertex2
      lon_vertices(3,i,nlat) = plon_vertex2
      lat_vertices(3,i,nlat) = plat_vertex1
      lon_vertices(4,i,nlat) = plon_vertex1
      lat_vertices(4,i,nlat) = plat_vertex1
  ENDDO


!... western and eastern edge
  DO j = 2, nlat -1
      plat_vertex1 = (plat(j+1) + plat(j)) / 2.
      plat_vertex2 = (plat(j-1) + plat(j)) / 2.
      plon_vertex1 = plon(1) - (plon(2) - plon(1)) / 2.
      plon_vertex2 = (plon(2) + plon(1)) / 2.
      lon_vertices(1,1,j) = plon_vertex1
      lat_vertices(1,1,j) = plat_vertex2
      lon_vertices(2,1,j) = plon_vertex2
      lat_vertices(2,1,j) = plat_vertex2
      lon_vertices(3,1,j) = plon_vertex2
      lat_vertices(3,1,j) = plat_vertex1
      lon_vertices(4,1,j) = plon_vertex1
      lat_vertices(4,1,j) = plat_vertex1
      plon_vertex1 = (plon(nlon-1) + plon(nlon)) / 2.
      plon_vertex2 = plon(nlon) + (plon(nlon) - plon(nlon-1)) / 2.
      lon_vertices(1,nlon,j) = plon_vertex1
      lat_vertices(1,nlon,j) = plat_vertex2
      lon_vertices(2,nlon,j) = plon_vertex2
      lat_vertices(2,nlon,j) = plat_vertex2
      lon_vertices(3,nlon,j) = plon_vertex2
      lat_vertices(3,nlon,j) = plat_vertex1   
      lon_vertices(4,nlon,j) = plon_vertex1
      lat_vertices(4,nlon,j) = plat_vertex1
  ENDDO

!... South - West
      plat_vertex1 = (plat(2) + plat(1)) / 2.
      plat_vertex2 = plat(1) - (plat(2) - plat(1)) / 2.
      plon_vertex1 = plon(1) - (plon(2) - plon(1)) / 2.
      plon_vertex2 = (plon(2) + plon(1)) / 2.
      lon_vertices(1,1,1) = plon_vertex1
      lat_vertices(1,1,1) = plat_vertex2
      lon_vertices(2,1,1) = plon_vertex2
      lat_vertices(2,1,1) = plat_vertex2
      lon_vertices(3,1,1) = plon_vertex2
      lat_vertices(3,1,1) = plat_vertex1
      lon_vertices(4,1,1) = plon_vertex1
      lat_vertices(4,1,1) = plat_vertex1

!... North - West
      plat_vertex1 = plat(nlat) - (plat(nlat-1) - plat(nlat)) / 2.
      plat_vertex2 = (plat(nlat-1) + plat(nlat)) / 2.
      plon_vertex1 = plon(1) - (plon(2) - plon(1)) / 2.
      plon_vertex2 = (plon(2) + plon(1)) / 2.
      lon_vertices(1,1,nlat) = plon_vertex1
      lat_vertices(1,1,nlat) = plat_vertex2
      lon_vertices(2,1,nlat) = plon_vertex2
      lat_vertices(2,1,nlat) = plat_vertex2
      lon_vertices(3,1,nlat) = plon_vertex2
      lat_vertices(3,1,nlat) = plat_vertex1
      lon_vertices(4,1,nlat) = plon_vertex1
      lat_vertices(4,1,nlat) = plat_vertex1

!... North - East
      plat_vertex1 = plat(nlat) - (plat(nlat-1) - plat(nlat)) / 2.
      plat_vertex2 = (plat(nlat-1) + plat(nlat)) / 2.
      plon_vertex1 = (plon(nlon-1) + plon(nlon)) / 2.
      plon_vertex2 = plon(nlon) + (plon(nlon) - plon(nlon-1)) / 2.
      lon_vertices(1,nlon,nlat) = plon_vertex1
      lat_vertices(1,nlon,nlat) = plat_vertex2
      lon_vertices(2,nlon,nlat) = plon_vertex2
      lat_vertices(2,nlon,nlat) = plat_vertex2
      lon_vertices(3,nlon,nlat) = plon_vertex2
      lat_vertices(3,nlon,nlat) = plat_vertex1
      lon_vertices(4,nlon,nlat) = plon_vertex1
      lat_vertices(4,nlon,nlat) = plat_vertex1

!... South - East
      plat_vertex1 = (plat(2) + plat(1)) / 2.
      plat_vertex2 = plat(1) + (plat(1) - plat(2)) / 2.
      plon_vertex1 = (plon(nlon-1) + plon(nlon)) / 2.
      plon_vertex2 = plon(nlon) + (plon(nlon) - plon(nlon-1)) / 2.
      lon_vertices(1,nlon,1) = plon_vertex1
      lat_vertices(1,nlon,1) = plat_vertex2
      lon_vertices(2,nlon,1) = plon_vertex2
      lat_vertices(2,nlon,1) = plat_vertex2
      lon_vertices(3,nlon,1) = plon_vertex2
      lat_vertices(3,nlon,1) = plat_vertex1
      lon_vertices(4,nlon,1) = plon_vertex1
      lat_vertices(4,nlon,1) = plat_vertex1

!...............................................................
!... rotated grid
  ELSE IF (itype_grid == 2) THEN

  istatus = nf90_inq_varid(ncid, 'rlon', varid_plon)
  IF (istatus /= NF90_NOERR) THEN
    PRINT *, 'Error in nccd_get / nf90_inq_varid' 
    PRINT *, TRIM(NF90_strerror(istatus))
    PRINT *, 'rlon'
    STOP
  ENDIF
  istatus = nf90_inq_dimid(ncid, 'rlon', dimid_plon)
  IF (istatus /= NF90_NOERR) THEN
      PRINT 'Error in rlon / nf90_inq_dimid -- '// &
                TRIM(NF90_strerror(istatus))
      STOP
  ENDIF

  istatus = nf90_inquire_dimension(ncid, dimid_plon, len=nlon)
  IF (istatus /= NF90_NOERR) THEN
      PRINT *, 'Error in plon / nf90_inquire_dimension -- '// &
                TRIM(NF90_strerror(istatus))
      STOP
  ENDIF
  
  istatus = nf90_inq_varid(ncid, 'rlat', varid_plat)
  IF (istatus /= NF90_NOERR) THEN
    PRINT *, 'Error in nccd_get / nf90_inq_varid' 
    PRINT *, TRIM(NF90_strerror(istatus))
    PRINT *, 'rlat'
    STOP
  ENDIF

  istatus = nf90_inq_dimid(ncid, 'rlat', dimid_plat)
  IF (istatus /= NF90_NOERR) THEN
      PRINT *, 'Error in rlat / nf90_inq_dimid -- '// &
                TRIM(NF90_strerror(istatus))
      STOP
  ENDIF
 
  istatus = nf90_inquire_dimension(ncid, dimid_plat, len=nlat)
  IF (istatus /= NF90_NOERR) THEN
     PRINT *, 'Error in plon / nf90_inquire_dimension -- '// &
                TRIM(NF90_strerror(istatus))
      STOP
  ENDIF

  ALLOCATE (plon(nlon))
  ALLOCATE (plat(nlat))
  ALLOCATE (lon_vertices(4, nlon, nlat))
  ALLOCATE (lat_vertices(4, nlon, nlat))

! read the data values
  istatus = nf90_get_var (ncid, varid_plon, plon)
  IF (istatus /= NF90_NOERR) THEN
    PRINT *, 'Error in plon nf90_get_var' 
    PRINT *, TRIM(NF90_strerror(istatus))
    STOP
  ENDIF

  istatus = nf90_get_var (ncid, varid_plat, plat)
  IF (istatus /= NF90_NOERR) THEN
    PRINT *, 'Error in plon nf90_get_var' 
    PRINT *, TRIM(NF90_strerror(istatus))
    STOP
  ENDIF

  istatus = nf90_redef(ncid)

  istatus=nf90_def_dim(ncid,"nv", 4, dimid_vertices)
  IF (istatus /= NF90_NOERR) THEN
    PRINT *, 'Error in nf90_def_dim of vertices'
    PRINT *, TRIM(NF90_strerror(istatus))
    RETURN
  ENDIF

! geographic longitude
  istatus=nf90_def_var(ncid, "lon_bnds", NF90_FLOAT, (/ dimid_vertices, dimid_plon, dimid_plat /), varid_lon_vertices)
  IF (istatus /= NF90_NOERR) THEN
    PRINT *,TRIM(NF90_strerror(istatus))
    STOP
  ENDIF

  istatus=nf90_put_att(ncid, varid_lon_vertices, "units", "degrees_east")
  IF (istatus /= NF90_NOERR) THEN
    PRINT *,TRIM(NF90_strerror(istatus))
    STOP
  ENDIF

  ! geographic latitude
  istatus=nf90_def_var(ncid, "lat_bnds", NF90_FLOAT, (/ dimid_vertices, dimid_plon, dimid_plat /), varid_lat_vertices)
  IF (istatus /= NF90_NOERR) THEN
    PRINT *,TRIM(NF90_strerror(istatus))
    STOP
  ENDIF
  istatus=nf90_put_att(ncid, varid_lat_vertices, "units", "degrees_north")
  IF (istatus /= NF90_NOERR) THEN
    PRINT *,TRIM(NF90_strerror(istatus))
    STOP
  ENDIF

  ! add attribute "bounds" to lon and lat

  istatus = nf90_inq_varid(ncid, 'lon', varid_lon)
  IF (istatus /= NF90_NOERR) THEN
    PRINT *, 'Error in nccd_get / nf90_inq_varid' 
    PRINT *, TRIM(NF90_strerror(istatus))
    PRINT *, 'lon'
    STOP
  ENDIF

  istatus=nf90_put_att(ncid, varid_lon, "bounds", "lon_bnds")
  IF (istatus /= NF90_NOERR) THEN
    PRINT *,TRIM(NF90_strerror(istatus))
    STOP
  ENDIF

  istatus = nf90_inq_varid(ncid, 'lat', varid_lat)
  IF (istatus /= NF90_NOERR) THEN
    PRINT *, 'Error in nccd_get / nf90_inq_varid' 
    PRINT *, TRIM(NF90_strerror(istatus))
    PRINT *, 'lat'
    STOP
  ENDIF
   istatus=nf90_put_att(ncid, varid_lat, "bounds", "lat_bnds")
  IF (istatus /= NF90_NOERR) THEN
    PRINT *,TRIM(NF90_strerror(istatus))
    STOP
  ENDIF


  istatus = nf90_enddef(ncid)
  
!... calculate vertices
  DO j = 2, nlat-1
    DO i = 2, nlon-1
      plat_vertex1 = (plat(j+1) + plat(j)) / 2.
      plat_vertex2 = (plat(j-1) + plat(j)) / 2.
      plon_vertex1 = (plon(i-1) + plon(i)) / 2.
      plon_vertex2 = (plon(i+1) + plon(i)) / 2.
      CALL rot2geo (plat_vertex2, plon_vertex1, pollat, pollon, polgam, lat_vertices(1,i,j), lon_vertices(1,i,j))
      CALL rot2geo (plat_vertex2, plon_vertex2, pollat, pollon, polgam, lat_vertices(2,i,j), lon_vertices(2,i,j))
      CALL rot2geo (plat_vertex1, plon_vertex2, pollat, pollon, polgam, lat_vertices(3,i,j), lon_vertices(3,i,j))
      CALL rot2geo (plat_vertex1, plon_vertex1, pollat, pollon, polgam, lat_vertices(4,i,j), lon_vertices(4,i,j))
    ENDDO
  ENDDO

!... northern edge and southern edge
  DO i = 2, nlon -1
      plat_vertex1 = (plat(2) + plat(1)) / 2.
      plat_vertex2 = plat(1) + (plat(1) - plat(2)) / 2.
      plon_vertex1 = (plon(i-1) + plon(i)) / 2.
      plon_vertex2 = (plon(i+1) + plon(i)) / 2.
      CALL rot2geo (plat_vertex2, plon_vertex1, pollat, pollon, polgam, lat_vertices(1,i,1), lon_vertices(1,i,1))
      CALL rot2geo (plat_vertex2, plon_vertex2, pollat, pollon, polgam, lat_vertices(2,i,1), lon_vertices(2,i,1))
      CALL rot2geo (plat_vertex1, plon_vertex2, pollat, pollon, polgam, lat_vertices(3,i,1), lon_vertices(3,i,1))
      CALL rot2geo (plat_vertex1, plon_vertex1, pollat, pollon, polgam, lat_vertices(4,i,1), lon_vertices(4,i,1))
      plat_vertex1 = plat(nlat) - (plat(nlat-1) - plat(nlat)) / 2.
      plat_vertex2 = (plat(nlat-1) + plat(nlat)) / 2.
      CALL rot2geo (plat_vertex2, plon_vertex1, pollat, pollon, polgam, lat_vertices(1,i,nlat), lon_vertices(1,i,nlat))
      CALL rot2geo (plat_vertex2, plon_vertex2, pollat, pollon, polgam, lat_vertices(2,i,nlat), lon_vertices(2,i,nlat))
      CALL rot2geo (plat_vertex1, plon_vertex2, pollat, pollon, polgam, lat_vertices(3,i,nlat), lon_vertices(3,i,nlat))
      CALL rot2geo (plat_vertex1, plon_vertex1, pollat, pollon, polgam, lat_vertices(4,i,nlat), lon_vertices(4,i,nlat))
  ENDDO


!... western and eastern edge
  DO j = 2, nlat -1
      plat_vertex1 = (plat(j+1) + plat(j)) / 2.
      plat_vertex2 = (plat(j-1) + plat(j)) / 2.
      plon_vertex1 = plon(1) - (plon(2) - plon(1)) / 2.
      plon_vertex2 = (plon(2) + plon(1)) / 2.
      CALL rot2geo (plat_vertex2, plon_vertex1, pollat, pollon, polgam, lat_vertices(1,1,j), lon_vertices(1,1,j))
      CALL rot2geo (plat_vertex2, plon_vertex2, pollat, pollon, polgam, lat_vertices(2,1,j), lon_vertices(2,1,j))
      CALL rot2geo (plat_vertex1, plon_vertex2, pollat, pollon, polgam, lat_vertices(3,1,j), lon_vertices(3,1,j))
      CALL rot2geo (plat_vertex1, plon_vertex1, pollat, pollon, polgam, lat_vertices(4,1,j), lon_vertices(4,1,j))
      plon_vertex1 = (plon(nlon-1) + plon(nlon)) / 2.
      plon_vertex2 = plon(nlon) + (plon(nlon) - plon(nlon-1)) / 2.
      CALL rot2geo (plat_vertex2, plon_vertex1, pollat, pollon, polgam, lat_vertices(1,nlon,j), lon_vertices(1,nlon,j))
      CALL rot2geo (plat_vertex2, plon_vertex2, pollat, pollon, polgam, lat_vertices(2,nlon,j), lon_vertices(2,nlon,j))
      CALL rot2geo (plat_vertex1, plon_vertex2, pollat, pollon, polgam, lat_vertices(3,nlon,j), lon_vertices(3,nlon,j))
      CALL rot2geo (plat_vertex1, plon_vertex1, pollat, pollon, polgam, lat_vertices(4,nlon,j), lon_vertices(4,nlon,j))
  ENDDO

!... South - West
      plat_vertex1 = (plat(2) + plat(1)) / 2.
      plat_vertex2 = plat(1) - (plat(2) - plat(1)) / 2.
      plon_vertex1 = plon(1) - (plon(2) - plon(1)) / 2.
      plon_vertex2 = (plon(2) + plon(1)) / 2.
      CALL rot2geo (plat_vertex2, plon_vertex1, pollat, pollon, polgam, lat_vertices(1,1,1), lon_vertices(1,1,1))
      CALL rot2geo (plat_vertex2, plon_vertex2, pollat, pollon, polgam, lat_vertices(2,1,1), lon_vertices(2,1,1))
      CALL rot2geo (plat_vertex1, plon_vertex2, pollat, pollon, polgam, lat_vertices(3,1,1), lon_vertices(3,1,1))
      CALL rot2geo (plat_vertex1, plon_vertex1, pollat, pollon, polgam, lat_vertices(4,1,1), lon_vertices(4,1,1))

!... North - West
      plat_vertex1 = plat(nlat) - (plat(nlat-1) - plat(nlat)) / 2.
      plat_vertex2 = (plat(nlat-1) + plat(nlat)) / 2.
      plon_vertex1 = plon(1) - (plon(2) - plon(1)) / 2.
      plon_vertex2 = (plon(2) + plon(1)) / 2.
      CALL rot2geo (plat_vertex2, plon_vertex1, pollat, pollon, polgam, lat_vertices(1,1,nlat), lon_vertices(1,1,nlat))
      CALL rot2geo (plat_vertex2, plon_vertex2, pollat, pollon, polgam, lat_vertices(2,1,nlat), lon_vertices(2,1,nlat))
      CALL rot2geo (plat_vertex1, plon_vertex2, pollat, pollon, polgam, lat_vertices(3,1,nlat), lon_vertices(3,1,nlat))
      CALL rot2geo (plat_vertex1, plon_vertex1, pollat, pollon, polgam, lat_vertices(4,1,nlat), lon_vertices(4,1,nlat))

!... North - East
      plat_vertex1 = plat(nlat) - (plat(nlat-1) - plat(nlat)) / 2.
      plat_vertex2 = (plat(nlat-1) + plat(nlat)) / 2.
      plon_vertex1 = (plon(nlon-1) + plon(nlon)) / 2.
      plon_vertex2 = plon(nlon) + (plon(nlon) - plon(nlon-1)) / 2.
      CALL rot2geo (plat_vertex2, plon_vertex1, pollat, pollon, polgam, lat_vertices(1,nlon,nlat), lon_vertices(1,nlon,nlat))
      CALL rot2geo (plat_vertex2, plon_vertex2, pollat, pollon, polgam, lat_vertices(2,nlon,nlat), lon_vertices(2,nlon,nlat))
      CALL rot2geo (plat_vertex1, plon_vertex2, pollat, pollon, polgam, lat_vertices(3,nlon,nlat), lon_vertices(3,nlon,nlat))
      CALL rot2geo (plat_vertex1, plon_vertex1, pollat, pollon, polgam, lat_vertices(4,nlon,nlat), lon_vertices(4,nlon,nlat))

!... South - East
      plat_vertex1 = (plat(2) + plat(1)) / 2.
      plat_vertex2 = plat(1) + (plat(1) - plat(2)) / 2.
      plon_vertex1 = (plon(nlon-1) + plon(nlon)) / 2.
      plon_vertex2 = plon(nlon) + (plon(nlon) - plon(nlon-1)) / 2.
      CALL rot2geo (plat_vertex2, plon_vertex1, pollat, pollon, polgam, lat_vertices(1,nlon,1), lon_vertices(1,nlon,1))
      CALL rot2geo (plat_vertex2, plon_vertex2, pollat, pollon, polgam, lat_vertices(2,nlon,1), lon_vertices(2,nlon,1))
      CALL rot2geo (plat_vertex1, plon_vertex2, pollat, pollon, polgam, lat_vertices(3,nlon,1), lon_vertices(3,nlon,1))
      CALL rot2geo (plat_vertex1, plon_vertex1, pollat, pollon, polgam, lat_vertices(4,nlon,1), lon_vertices(4,nlon,1))

  ENDIF ! of itype_grid

  istatus = nf90_put_var (ncid, varid_lon_vertices, lon_vertices)
  IF (istatus /= NF90_NOERR) THEN
    PRINT *,TRIM(NF90_strerror(istatus)) // 'in put_var lon_vertices'
    STOP
  ENDIF
  istatus = nf90_put_var (ncid, varid_lat_vertices, lat_vertices)
  IF (istatus /= NF90_NOERR) THEN
    PRINT *,TRIM(NF90_strerror(istatus)) // 'in put_var lat_vertices'
    STOP
  ENDIF


  istatus = nf90_close(ncid)
   IF (istatus /= NF90_NOERR) THEN
    PRINT *,TRIM(NF90_strerror(istatus))
    STOP
  ENDIF

  DEALLOCATE (plon, plat, lon_vertices, lat_vertices)

 
END SUBROUTINE add_vertices


