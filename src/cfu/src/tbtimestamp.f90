SUBROUTINE tbtimestamp (ncfile, itype_calendar)

!-------------------------------------------------------------------------------
!
! Description:
!   This program prints the time stamp of the time_bnds variable
!
!   Usage:
!     tbtimestamp <ncfile> <itype_calendar>
!
!   The result is written to standard output in the form YYYY-MM-DDThh:mm:ss
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
  USE mo_utilities

  IMPLICIT NONE

! Input Parameter list:
! ---------------------

  CHARACTER (LEN=*) :: &
    ncfile                ! name of NetCDF file

  INTEGER, INTENT(IN) :: &
    itype_calendar  ! type of calendar 
                    ! 0 = standard calendar
                    ! 1 = climatological calendar (360 days per year)
                    ! 2 = 365 days per year

! Parameter written to standard output
! ------------------------------------

  CHARACTER (LEN=19), ALLOCATABLE          ::                           &
    timestamp(:,:)  !

! Local variables:
! ------------------------------------

  INTEGER :: &
    istatus,       &
    ncid,          &
    varid, timeid, &
    vardimids(2),  &
    ntime,         &
    izdb,          &
    i, j,          &
    izyear_ref,izmonth_ref,izday_ref,izhour_ref,izmin_ref,izsec_ref

  REAL(KIND=8), ALLOCATABLE :: &
    time_bnds(:,:)    

  REAL(KIND=8)    :: &
    ztimemul    

  CHARACTER (LEN=40) :: &
    yzdate1           ! time unit and reference date from input

  CHARACTER (LEN=14) :: &
    ystart_date, yact_date         


! open the data file
  istatus = nf90_open(ncfile, NF90_NOWRITE, ncid)
  IF (istatus /= NF90_NOERR) THEN
    PRINT *, 'ERROR in opening ',TRIM(ncfile)
    STOP
  ENDIF



  istatus = nf90_inq_varid(ncid, "time_bnds", varid)
  IF (istatus /= NF90_NOERR) THEN
    PRINT *, 'ERROR: Variable time_bnds not found'
    STOP
  ENDIF
  

  istatus = nf90_inquire_variable(ncid, varid, dimids = vardimids)
  
  istatus = nf90_inquire_dimension(ncid, vardimids(2), len = ntime)
  
  ALLOCATE (time_bnds(2,ntime), timestamp(2,ntime))
  
  istatus = nf90_get_var(ncid, varid, time_bnds)
  
  istatus = nf90_get_att (ncid, varid, 'units', yzdate1)
  IF (istatus /= NF90_NOERR) THEN
  ! no units for time_bnds found, try to take that one from time
    istatus = nf90_inq_varid(ncid, "time", timeid)
    IF (istatus /= NF90_NOERR) THEN
      PRINT *, 'ERROR: Variable time not found'
      STOP
    ENDIF
    istatus = nf90_get_att (ncid, timeid, 'units', yzdate1)
    IF (istatus /= NF90_NOERR) THEN
      PRINT *, 'ERROR: No time units found'
      STOP
    ENDIF
  ENDIF

  !   determine time units
  izdb = index(yzdate1,'seconds')
  IF (izdb /= 0) THEN
    ztimemul = 1.0
  ELSE
    izdb = index(yzdate1,'minutes')
    IF (izdb /= 0) THEN
      ztimemul = 60.0
    ELSE
      izdb = index(yzdate1,'hours')
      IF (izdb /= 0) THEN
        ztimemul = 3600.0
      ELSE
        izdb = index(yzdate1,'days')
        IF (izdb /= 0) THEN
          ztimemul = 86400.0
        ELSE
          PRINT *, 'No valid time units found. Must be seconds, minutes, hours or days'
          STOP
        ENDIF
      ENDIF
    ENDIF
  ENDIF
  
  time_bnds(:,:) = time_bnds(:,:) * ztimemul

  DO i = 1,LEN_TRIM(yzdate1)
    IF(ICHAR(yzdate1(i:i)) < 48 .OR. ICHAR(yzdate1(i:i)) > 57) yzdate1(i:i)=' '
  ENDDO

  izdb = index(yzdate1,'since') + 5

  READ(yzdate1(izdb:),*,IOSTAT=istatus) izyear_ref,izmonth_ref,izday_ref,izhour_ref,izmin_ref,izsec_ref
  WRITE(ystart_date,'(I4,5(I2))') izyear_ref,izmonth_ref,izday_ref,izhour_ref,izmin_ref,izsec_ref
  
  DO j = 1,ntime
    DO i = 1,2
      CALL calc_utc_date (ystart_date, time_bnds(i,j), itype_calendar, yact_date)      
      timestamp(i,j) = yact_date(1:4)//'-'//yact_date(5:6)//'-'//yact_date(7:8)//'T'//yact_date(9:10)//':'//yact_date(11:12)//':'//yact_date(13:14)
    ENDDO
  ENDDO
  
  write(*,'(A)') timestamp

  DEALLOCATE (time_bnds, timestamp)
  
  istatus = nf90_close(ncid)


!------------ End of header ----------------------------------------------------

! Begin subroutine tbtimestamp


END SUBROUTINE tbtimestamp

