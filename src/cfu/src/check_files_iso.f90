SUBROUTINE check_files_iso (ystartdate, yenddate, yinterval, yprefix1, yprefix2, ysuffix, inpdir, lastoutput, itype_calendar)

!
! Purpose: checks whether all necessary data files are available of the following file syntax
!          <prefix>yyyymmddThhmmssZ<suffix>
!
!          Output on standard device: 0 = all files found
!                                     1 = missing files exist
!          Output on file "check_files.log" : listing of files
!
!.....................................................
! Copyright 2021 Helmholtz-Zentrum Hereon
! Copyright 2019-2020 Helmholtz-Zentrum Geesthacht
! Licensed under the GNU License, Version 3.0
! (https://www.gnu.org/licenses/gpl-3.0.html)
! Author(s): Burkhardt Rockel (Hereon)
!.....................................................
!

  USE mo_utilities

  IMPLICIT NONE

  INTEGER, PARAMETER       ::                                         &
       ireals    = SELECTED_REAL_KIND (12,200),                       &
       int_dp    = SELECTED_INT_KIND (12)

! Input Parameter list:
! ---------------------

  CHARACTER (LEN=*), INTENT(IN) :: &
    inpdir

  INTEGER , INTENT(IN) :: &
    itype_calendar  ! type of calendar 
                    ! 0 = standard calendar
                    ! 1 = climatological calendar (360 days per year)
                    ! 2 = climatological calendar (365 days per year)

  LOGICAL, INTENT(IN) :: &
    lastoutput      ! = true, if the last output file should be checked

  CHARACTER (LEN=14) :: &
    ystartdate,     &
    yenddate,       &
    yinterval

  CHARACTER (LEN=*)  , INTENT(IN) :: &
    yprefix1,        &
    yprefix2,        &
    ysuffix

! Local variables:
! ------------------------------------

  INTEGER :: &
    inctime, &   ! in seconds
    inchours, &
    incminutes, &
    incseconds

  CHARACTER (LEN=250) :: &
    bndfile1, bndfile2

  CHARACTER (LEN=14) :: &
    yactdate

  CHARACTER (LEN=8) :: &
    yinterval_str

  CHARACTER (LEN=2) :: &
    yhh, yss

  INTEGER :: &
    iargc,        &
    hh_start,     &
    hh_end,       &
    hh_add,       &
    hours,        &
    endhours

  INTEGER :: &
    ss_start,     &
    ss_end,       &
    ss_add

  INTEGER (KIND=int_dp) :: &
    seconds,  &
    endseconds

  LOGICAL :: &
    lexist,   &
    lok=.TRUE.

  
    READ(yinterval(1:2),'(I2)') inchours
    READ(yinterval(4:5),'(I2)') incminutes
    READ(yinterval(7:8),'(I2)') incseconds
    inctime = inchours * 3600 + incminutes * 60 + incseconds
    OPEN (1, FILE='check_files.log',form='formatted')

    yss = ystartdate(13:14)
    READ(yss,'(I2)') ss_start
    ss_start = ss_start - MOD(ss_start,inctime)
    WRITE(yss,'(I2.2)') ss_start
    ystartdate(13:14) = yss
    yss = yenddate(13:14)
    READ(yss,'(I2)') ss_end
    ss_add = inctime - MOD(ss_end,inctime)
    IF (ss_add == inctime) ss_add = 0
    
    IF (ss_add /= inctime) THEN
     CALL calc_utc_date (yenddate, REAL(ss_add,ireals), itype_calendar, yactdate)
      yenddate = yactdate
    ENDIF
    
   CALL calc_seconds (ystartdate, yenddate, itype_calendar, endseconds)
  
    seconds = 0
   
    IF (.NOT. lastoutput) endseconds = endseconds - inctime
  
    DO WHILE (seconds <= endseconds)
  
      CALL calc_utc_date (ystartdate, REAL(seconds,ireals), itype_calendar, yactdate)
      bndfile1 = TRIM(inpdir)//'/'//TRIM(yprefix1)//yactdate(1:8)//'T'//yactdate(9:14)//'Z'//TRIM(ysuffix)
      !... check if boundary file exists
      INQUIRE(file=bndfile1,exist=lexist)
      IF (.NOT. lexist) THEN
        IF ( TRIM(yprefix1) == TRIM(yprefix2)) THEN
          WRITE (1,'(A,A)') TRIM(bndfile1),' -- does not exist'
          lok = .FALSE.
        ELSE
          bndfile2 = TRIM(inpdir)//'/'//TRIM(yprefix2)//yactdate(1:8)//'T'//yactdate(9:14)//'Z'//TRIM(ysuffix)
          INQUIRE(file=bndfile2,exist=lexist)
          IF (.NOT. lexist) THEN
            WRITE (1,'(A,A)') TRIM(bndfile1),' -- does not exist'
            WRITE (1,'(A,A)') TRIM(bndfile2),' -- does not exist'
            lok = .FALSE.
!          ELSE
!            WRITE (1,*) TRIM(bndfile1),' found'
          ENDIF
       ENDIF
  !      PRINT *, 'missing file: ',TRIM(bndfile)
!      ELSE
!        WRITE (1,*) TRIM(bndfile1),' found'
      ENDIF
   
      seconds = seconds + inctime
    ENDDO
  
  
    IF (lok) THEN
      CLOSE (1, status='delete')
      write (*,'(A1)') '0'
    ELSE
      CLOSE (1)
      write (*,'(A1)') '1'
    ENDIF


END SUBROUTINE check_files_iso

