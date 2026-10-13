MODULE mo_create_rotgrid

!-------------------------------------------------------------------------------
!
! Description:
!   This program creates lon/lat grid values and lon/lat grid vertices for a rotated grid
!
!   Usage:
!     create_rotgrid <startrlon> <startrlat> <drlon> <drlat> <nrlon> <nrlat> <pollon> <pollat> <polgam> <grid file>
!
!   The results are written to the <grid file> in netCDF format
!
!.....................................................
! Copyright 2021 Helmholtz-Zentrum Hereon
! Licensed under the GNU License, Version 3.0
! (https://www.gnu.org/licenses/gpl-3.0.html)
! Author(s): Burkhardt Rockel (Hereon), Klaus Keuler (BTU Cottbus)
!.....................................................
!
!-------------------------------------------------------------------------------
!

USE mo_kind
USE mo_utilities
USE netcdf

IMPLICIT NONE

!==============================================================================

CONTAINS

!==============================================================================

SUBROUTINE create_rotgrid (startlon, startlat, dlon, dlat, nlon, nlat, pollon, pollat, polgam, ncfile)
!
!  PURPOSE: Create rotated grid description netCDF file
!
!  CALL: create_rotgrid STARTLON STARTLAT DLON DLAT NLON NLAT POLLON POLLAT POLGAM NCFILE
!


!... Arguments
REAL (KIND=wp) :: &
  startlon, &  ! longitude of lower left corner in rotated coordinates
  startlat, &  ! latitude of lower left corner in rotated coordinates
  dlon,     &  ! longitudinal grid with in rotated coordinates
  dlat,     &  ! latitudinal grid with in rotated coordinates
  pollon,   &  ! rotated coordinates of longitude of geographical North Pole
  pollat,   &  ! rotated coordinates of latitude of geographical North Pole
  polgam       ! rotated longitude shift of North Pole

INTEGER :: &
  nlon,     &  ! number of grid points in longitudinal direction
  nlat         ! number of grid points in latitudinal direction

CHARACTER (LEN=250) :: &
  ncfile       ! netCDF file receiving the grid information


CHARACTER (LEN=250) :: &
  carg         ! help variable to get the non-character program arguments


INTEGER, PARAMETER :: &
  nv=4             ! number of vertices

INTEGER :: &
  i, j, k,       & ! indices
  status           ! return status of a function

INTEGER :: &
  ncid,          & ! ID of the netCDF file
  rlondimid,     & ! dimID of rotated longitudes
  rlatdimid,     & ! dimID of rotated latitudes
  nvdimid,       & ! dimID of number of vertices
  rlonid,        & ! varID of rlon
  rlatid,        & ! varID of rlat
  rotpolid,      & ! varID of the rotated pole
  lonid,         & ! varID of lon
  latid,         & ! varID of lat
  lonverticesid, & ! varID of lon_vertices
  latverticesid, & ! varID of lat_vertices
  dummyid          ! varID of dummy array

REAL (KIND=wp), ALLOCATABLE ::   &
  rlon(:),             & ! rotated longitudes
  rlat(:),             & ! rotated latitudes
  lon(:,:),            & ! geographical longitudes
  lat(:,:),            & ! geographical latitudes
  lon_vertices(:,:,:), & ! geographical longitude values of vertices
  lat_vertices(:,:,:), & ! geographical latitude values of vertices
  dummy(:,:)             ! a dummy array holding just 0 values (needed e.g. by CDO for remapping)

!... allocate fields
ALLOCATE (rlon(nlon), rlat(nlat))
ALLOCATE (lon(nlon,nlat), lat(nlon,nlat))
ALLOCATE (lon_vertices(nv,nlon,nlat), lat_vertices(nv,nlon,nlat))
ALLOCATE (dummy(nlon,nlat))

!... preset dummy array with 0 values
dummy = 0.

!... calculate rlon and rlat values
DO i = 1, nlon
  rlon(i) = startlon + (i-1)*dlon
ENDDO
DO j = 1, nlat
  rlat(j) = startlat + (j-1)*dlat
ENDDO


!... calculate geographical longitudes and latitudes and the vertices
CALL calc_lon_lat_vertices (nlon, nlat, rlon, rlat, pollon, pollat, polgam, lon, lat, lon_vertices, lat_vertices)

!... calculate geographical coordinates


!... create netCDF file (overwrite any exiting file with the same name)
status = nf90_create(path = TRIM(ncfile), cmode = nf90_clobber, ncid = ncid)
IF (status /= nf90_noerr) CALL handle_error(status)

!... define dimensions
status = nf90_def_dim(ncid, "rlon", nlon, rlondimid)
IF (status /= nf90_noerr) CALL handle_error(status)
status = nf90_def_dim(ncid, "rlat", nlat, rlatdimid)
IF (status /= nf90_noerr) CALL handle_error(status)
status = nf90_def_dim(ncid, "nv", nv, nvdimid)
IF (status /= nf90_noerr) CALL handle_error(status)

!... define variables
status = nf90_def_var(ncid, "rlon", nf90_float, &
                      (/ rlondimid /), rlonid)
IF (status /= nf90_noerr) CALL handle_error(status)
status = nf90_def_var(ncid, "rlat", nf90_float, &
                      (/ rlatdimid /), rlatid)
IF (status /= nf90_noerr) CALL handle_error(status)
status = nf90_def_var(ncid, "lon", nf90_float, &
                      (/ rlondimid, rlatdimid /), lonid)
IF (status /= nf90_noerr) CALL handle_error(status)
status = nf90_def_var(ncid, "lat", nf90_float, &
                      (/ rlondimid, rlatdimid /), latid)
IF (status /= nf90_noerr) CALL handle_error(status)
status = nf90_def_var(ncid, "lon_vertices", nf90_float, &
                      (/ nvdimid, rlondimid, rlatdimid /), lonverticesid)
IF (status /= nf90_noerr) CALL handle_error(status)
status = nf90_def_var(ncid, "lat_vertices", nf90_float, &
                      (/ nvdimid, rlondimid, rlatdimid /), latverticesid)
IF (status /= nf90_noerr) CALL handle_error(status)
status = nf90_def_var(ncid, "dummy", nf90_float, &
                      (/ rlondimid, rlatdimid /), dummyid)
IF (status /= nf90_noerr) CALL handle_error(status)
status = nf90_def_var(ncid, "rotated_pole", nf90_char, rotpolid)
IF (status /= nf90_noerr) CALL handle_error(status)

!... define attributes
!  for the dummy array
status=nf90_put_att(ncid, dummyid, "coordinates", "lon lat")
IF (status /= nf90_noerr) CALL handle_error(status)
status=nf90_put_att(ncid, dummyid, "grid_mapping", "rotated_pole")
IF (status /= nf90_noerr) CALL handle_error(status)

! for lat and lon
status=nf90_put_att(ncid, lonid, "standard_name", "longitude")
IF (status /= nf90_noerr) CALL handle_error(status)
status=nf90_put_att(ncid, lonid, "long_name", "geographical longitude")
IF (status /= nf90_noerr) CALL handle_error(status)
status=nf90_put_att(ncid, lonid, "units", "degrees_east")
IF (status /= nf90_noerr) CALL handle_error(status)
status=nf90_put_att(ncid, lonid, "bounds", "lon_vertices")

IF (status /= nf90_noerr) CALL handle_error(status)
status=nf90_put_att(ncid, latid, "standard_name", "latitude")
IF (status /= nf90_noerr) CALL handle_error(status)
status=nf90_put_att(ncid, latid, "long_name", "geographical latitude")
IF (status /= nf90_noerr) CALL handle_error(status)
status=nf90_put_att(ncid, latid, "units", "degrees_north")
IF (status /= nf90_noerr) CALL handle_error(status)
status=nf90_put_att(ncid, latid, "bounds", "lat_vertices")
IF (status /= nf90_noerr) CALL handle_error(status)

! for lon_vertices and lat_vertices
status=nf90_put_att(ncid, lonverticesid, "long_name", "geographical longitude of vertices")
IF (status /= nf90_noerr) CALL handle_error(status)
status=nf90_put_att(ncid, lonverticesid, "units", "degrees_east")
IF (status /= nf90_noerr) CALL handle_error(status)

status=nf90_put_att(ncid, latverticesid, "long_name", "geographical latitude of vertices")
IF (status /= nf90_noerr) CALL handle_error(status)
status=nf90_put_att(ncid, latverticesid, "units", "degrees_east")
IF (status /= nf90_noerr) CALL handle_error(status)
IF (status /= nf90_noerr) CALL handle_error(status)

! for rlon and rlat
status=nf90_put_att(ncid, rlonid, "standard_name", "grid_longitude")
IF (status /= nf90_noerr) CALL handle_error(status)
status=nf90_put_att(ncid, rlonid, "long_name", "rotated longitudes")
IF (status /= nf90_noerr) CALL handle_error(status)
status=nf90_put_att(ncid, rlonid, "units", "degrees")
IF (status /= nf90_noerr) CALL handle_error(status)

status=nf90_put_att(ncid, rlatid, "standard_name", "grid_latitude")
IF (status /= nf90_noerr) CALL handle_error(status)
status=nf90_put_att(ncid, rlatid, "long_name", "rotated latitudes")
IF (status /= nf90_noerr) CALL handle_error(status)
status=nf90_put_att(ncid, rlatid, "units", "degrees")
IF (status /= nf90_noerr) CALL handle_error(status)

! for the rotated pole
status=nf90_put_att(ncid, rotpolid, "long_name","coordinates of the rotated North Pole")
IF (status /= nf90_noerr) CALL handle_error(status)
  
status=nf90_put_att(ncid, rotpolid, "grid_mapping_name", "rotated_latitude_longitude")
IF (status /= nf90_noerr) CALL handle_error(status)
  
status=nf90_put_att(ncid, rotpolid, "grid_north_pole_longitude", pollon)
IF (status /= nf90_noerr) CALL handle_error(status)

status=nf90_put_att(ncid, rotpolid, "grid_north_pole_latitude", pollat)
IF (status /= nf90_noerr) CALL handle_error(status)
  
status=nf90_put_att(ncid, rotpolid, "north_pole_grid_longitude", polgam)
IF (status /= nf90_noerr) CALL handle_error(status)


!... end of definitions
status = nf90_enddef(ncid)
IF (status /= nf90_noerr) CALL handle_error(status)

!... write the variables
status=nf90_put_var(ncid, dummyid, dummy)
IF (status /= nf90_noerr) CALL handle_error(status)
status=nf90_put_var(ncid, lonid, lon)
IF (status /= nf90_noerr) CALL handle_error(status)
status=nf90_put_var(ncid, latid, lat)
IF (status /= nf90_noerr) CALL handle_error(status)
status=nf90_put_var(ncid, lonverticesid, lon_vertices)
IF (status /= nf90_noerr) CALL handle_error(status)
status=nf90_put_var(ncid, latverticesid, lat_vertices)
IF (status /= nf90_noerr) CALL handle_error(status)
status=nf90_put_var(ncid, rlonid, REAL(rlon))
IF (status /= nf90_noerr) CALL handle_error(status)
status=nf90_put_var(ncid, rlatid, rlat)
IF (status /= nf90_noerr) CALL handle_error(status)

!... close the netCDF file

status=nf90_close(ncid)
IF (status /= nf90_noerr) CALL handle_error(status)

!... deallocate fields
DEALLOCATE (rlon, rlat, lon, lat, lon_vertices, lat_vertices, dummy)


END SUBROUTINE create_rotgrid


SUBROUTINE calc_lon_lat_vertices (nlon, nlat, plon, plat, pollon, pollat, polgam, lon, lat, lon_vertices, lat_vertices)

!-------------------------------------------------------------------------------
!
! Description:
!   This subroutine claculates latitude and longitude vertices 
!!
!   Order of the vertices
!     4 ---- 3
!     |      |
!     1 ---- 2
!
!-------------------------------------------------------------------------------
!

! Input Parameter list:
! ---------------------

  INTEGER, INTENT(IN) :: &
  nlon,     &  ! number of grid points in longitudinal direction
  nlat         ! number of grid points in latitudinal direction

  REAL (KIND=wp), INTENT(IN) :: &
  plon(nlon),    & ! rotated longitudes
  plat(nlat),    & ! rotated latitudes
  pollon,        & ! rotated coordinates of longitude of geographical North Pole
  pollat,        & ! rotated coordinates of latitude of geographical North Pole
  polgam           ! rotated longitude shift of North Pole

  REAL (KIND=wp), INTENT(OUT) :: &
  lon(nlon,nlat),            & ! geographical longitudes
  lat(nlon,nlat),            & ! geographical latitudes
  lon_vertices(4,nlon,nlat), & ! geographical longitude values of vertices
  lat_vertices(4,nlon,nlat)    ! geographical latitude values of vertices

! Local variables:
! ------------------------------------

  INTEGER :: &
    i, j, k     ! loop indices
      
  REAL (KIND=wp) :: &
    plat_vertex1, plat_vertex2, plon_vertex1, plon_vertex2 ! help variables
    

!------------ End of header ----------------------------------------------------

!... calculate geographical longitudes and latitudes
  DO j = 1, nlat
    DO i = 1, nlon
      CALL rot2geo (plat(j), plon(i), pollat, pollon, polgam, lat(i,j), lon(i,j))
    ENDDO
  ENDDO

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

 
END SUBROUTINE calc_lon_lat_vertices

END MODULE mo_create_rotgrid
