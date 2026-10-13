SUBROUTINE get_attval (ncfile, var_name, att_name)

!-------------------------------------------------------------------------------
!
! Description:
!   Get the value of a given attribute from a netCDF file
!
!   Usage:
!     get_attval <ncfile> <name of variable> <name of attribute>
!
!   The result is written to standard output
!
!.....................................................
! Copyright 2021 Helmholtz-Zentrum Hereon
! Copyright 2010-2020 Helmholtz-Zentrum Geesthacht
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
    ncfile,             & ! name of NetCDF file
    var_name,           & ! name of variable to be read
    att_name              ! name of attribute to be read


! Parameter written to standard output
! ------------------------------------

  CHARACTER (LEN=200) :: &
    att_value_char        ! character attribute value
  INTEGER, ALLOCATABLE :: &
    att_value_int(:)      ! integer attribute value
  REAL, ALLOCATABLE :: &
    att_value_float(:)    ! float attribute value
  REAL(KIND=8), ALLOCATABLE :: &
    att_value_double(:)   ! double attribute value


! Local variables:
! ------------------------------------

  INTEGER :: &
    istatus,            & ! status variable
    ncid,               & ! ID of the NetCDF file
    varid,              & ! ID of the variable "var_name"
    attlen,             & ! length of the attribute
    xtype                 ! type of the attribute. Valid type in the get_attval function are 
                          ! NF90_CHAR, NF90_INT, NF90_FLOAT, and NF90_DOUBLE


!- End of header
!------------------------------------------------------------------------------

!... get command-line argument
!  IF (iargc() < 3) THEN
!    PRINT *, ' ERROR: invalid number of arguments'
!    PRINT *, 'Usage: get_attval <ncfile> <varname> <attribute name>'
!    STOP
!  ENDIF

! get arguments
!  CALL getarg(1, ncfile)
!  CALL getarg(2, var_name)
!  CALL getarg(3, att_name)

! open the data file
  istatus = nf90_open(ncfile, NF90_NOWRITE, ncid)
  IF (istatus /= NF90_NOERR) THEN
!    WRITE (*,'(2H--)')
    STOP
  ENDIF

  IF (TRIM(var_name) == 'GLOBAL' .OR. TRIM(var_name) == 'global') THEN
    varid = NF90_GLOBAL
  ELSE
!   set the ID for the quantity "label"
    istatus = nf90_inq_varid(ncid, TRIM(var_name), varid)
  ENDIF

! inquire 

  istatus = nf90_inquire_attribute(ncid, varid, att_name, xtype, len=attlen)
! in case the attribute is not found write two minus signs
  IF (istatus /= NF90_NOERR) THEN
    WRITE (*,'(2H--)')
    istatus = nf90_close(ncid)
    STOP
  ENDIF        
  
  SELECT CASE (xtype)

    CASE (NF90_CHAR)
      IF(len(att_value_char) < attlen) THEN
        PRINT *, "ERROR: character length of attribute is longer than ",len(att_value_char)
        istatus = nf90_close(ncid)
        STOP
      ELSE
        istatus = nf90_get_att (ncid, varid, att_name, att_value_char)
        WRITE (*,'(A)') TRIM(att_value_char)
        STOP
      ENDIF

    CASE (NF90_INT)
      ALLOCATE(att_value_int(attlen), stat = istatus)
      istatus = nf90_get_att (ncid, varid, att_name, att_value_int)
      WRITE (*,*) att_value_int
      istatus = nf90_close(ncid)
      STOP

    CASE (NF90_FLOAT)
      ALLOCATE(att_value_float(attlen), stat = istatus)
      istatus = nf90_get_att (ncid, varid, att_name, att_value_float)
      WRITE (*,*) att_value_float
      istatus = nf90_close(ncid)
      STOP

    CASE (NF90_DOUBLE)
      ALLOCATE(att_value_double(attlen), stat = istatus)
      istatus = nf90_get_att (ncid, varid, att_name, att_value_double)
      WRITE (*,*) att_value_double
      istatus = nf90_close(ncid)
      STOP

    CASE DEFAULT
      PRINT *, 'ERROR: Invalid attribute format.'
      PRINT *, '  valid formats are character, integer, float and double'
      STOP

  END SELECT


END SUBROUTINE get_attval
