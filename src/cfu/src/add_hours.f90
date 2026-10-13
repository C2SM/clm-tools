SUBROUTINE add_hours (ystartdate, hadd, itype_calendar)

!-------------------------------------------------------------------------------
!
! Description:
!   This program adds a number of hours to a date
!   YYYYMMDDHH[MMSS](new) = YYYMMDDHH[MMSS](old) + hours
!
!   Usage:
!     add_hours <yyyymmddhh[mmss]> <hours> <itype_calendar>
!
!   The result is written to standard output in the form YYYYMMDDHH
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
  IMPLICIT NONE

! Input Parameter list:
! ---------------------

  CHARACTER (LEN=14) , INTENT(IN)          ::                      &
    ystartdate ! start date of the forecast

  REAL, INTENT(IN)      ::   &
    hadd      ! hours to be added to ystartdate

  INTEGER, INTENT(IN) :: &
    itype_calendar  ! type of calendar 
                    ! 0 = standard calendar
                    ! 1 = climatological calendar (360 days per year)
                    ! 2 = 365 days per year

! Parameter written to standard output
! ------------------------------------

  CHARACTER (LEN=14)          ::                           &
    yactdate1  ! actual date in the form   yyyymmddhh

! Local variables:
! ------------------------------------

  INTEGER      ::                                       &
    month(12), monthsum(13), ileap, iweek, iy, m,                       &
    idd, imm, iyy, ihh, iday, imonth, iyear, ihour, immhours, iyyhours
    CHARACTER (LEN=3)            :: yweek(7)
    CHARACTER (LEN=20)           :: chadd


!------------ End of header ----------------------------------------------------

! Begin subroutine add_hours

DATA         month  / 31 ,  28 ,  31 ,  30 ,  31 ,  30 ,       &
                      31 ,  31 ,  30 ,  31 ,  30 ,  31 /
DATA         yweek  /'MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN' /


! Statementfunction: ileap(yy) = 0:  no leap year, 
!                    ileap(yy) = 1:  leap year
  ileap (iy) = IABS( MOD(iy,  4) -   4) /   4  & ! every       4 years is a leapyear
              -IABS( MOD(iy,100) - 100) / 100  & ! every     100 years is no leapyear
              +IABS( MOD(iy,400) - 400) / 400    ! but every 400 years is a leapyear

! Divide ystartdate in day, month, year and hour
! and calculate the sums of days from the beginning of the year to the 
! end of the months
  READ ( ystartdate, '(I4,3I2)' ) iyy, imm, idd, ihh

   
  SELECT CASE (itype_calendar)
  
  CASE (0)   !  Standard year

  month (2)    = 28 + ileap (iyy)
  monthsum(1) =  0
  DO m =  2 , 13
    monthsum(m) =  monthsum(m-1) + month(m-1)
  enddo

! Determine how many hours have passed in this year
  iyyhours = (idd*24) + monthsum(imm)*24 + (ihh-24)
  iyyhours = iyyhours + hadd
! Take turning of the year into account
    IF (iyyhours < 0) THEN
      iyear    = iyy -1
      DO
        iyyhours = iyyhours + (8760 + ileap(iyear)*24)
        IF (iyyhours >= 0) EXIT
        iyear = iyear - 1
      END DO
      month (2)    = 28 + ileap (iyear)
      monthsum(1) =  0
      DO m =  2 , 13
          monthsum(m) =  monthsum(m-1) + month(m-1)
      ENDDO
    ELSE IF (iyyhours >= (8760+ileap(iyy)*24)) THEN
      ! Take also into account if the run lasts
      ! for several years
      iyear    = iyy
      DO WHILE (iyyhours >= (8760+ileap(iyear)*24))
       iyyhours = iyyhours - (8760+ileap(iyear)*24)
       iyear=iyear+1
       month (2)    = 28 + ileap (iyear)
       monthsum(1) =  0
       DO m =  2 , 13
           monthsum(m) =  monthsum(m-1) + month(m-1)
       ENDDO
      ENDDO
    ELSE
      iyear    =   iyy
    ENDIF

! Determine the actual date from iyyhours
  m        = 1
  immhours = iyyhours
  DO WHILE (immhours >= 0)
    m        = m+1
    immhours = iyyhours - monthsum(m) * 24
  ENDDO
  imonth   = m-1
  immhours = iyyhours - monthsum(imonth)*24
  iday     = immhours/24 + 1
  ihour    = MOD(immhours,24)
  iweek    = MOD(monthsum(imonth) + iday + (iyear-1981)+(iyear-1981)/4+2 , 7) + 1

  WRITE ( yactdate1(1:4) , '(I4.4)' ) iyear
  WRITE ( yactdate1(5:6) , '(I2.2)' ) imonth
  WRITE ( yactdate1(7:8) , '(I2.2)' ) iday
  WRITE ( yactdate1(9:10), '(I2.2)' ) ihour
  IF (LEN(TRIM(ystartdate)) == 14) THEN
    yactdate1(11:14) = ystartdate(11:14)
    write(*,'(A14)') yactdate1
  ELSE
    write(*,'(A10)') yactdate1(1:10)
  ENDIF

!.... 
  CASE (1)   !  360 days per year

  monthsum(1) =  0
  DO m =  2 , 13
    monthsum(m) =  monthsum(m-1) + 30
  enddo

! Determine how many hours have passed in this year
  iyyhours = (idd*24) + monthsum(imm)*24 + (ihh-24)
  iyyhours = iyyhours + hadd

! Take turning of the year into account
  IF (iyyhours < 0) THEN
    iyear    = iyy-1
    iyyhours = 8640  + iyyhours
  ELSE IF (iyyhours >= 8640) THEN
      iyear    = iyy
    DO WHILE (iyyhours >= 8640)
      iyear    = iyear+1
      iyyhours = iyyhours - 8640
    ENDDO
  ELSE
    iyear    =   iyy
  ENDIF

! Determine the actual date from iyyhours
  m        = 1
  immhours = iyyhours
  DO WHILE (immhours >= 0)
    m        = m+1
    immhours = iyyhours - monthsum(m) * 24
  ENDDO
  imonth   = m-1
  immhours = iyyhours - monthsum(imonth)*24
  iday     = immhours/24 + 1
  ihour    = MOD(immhours,24)
  iweek    = MOD(monthsum(imonth) + iday + (iyear-1981) , 7) + 1

  WRITE ( yactdate1(1:4) , '(I4.4)' ) iyear
  WRITE ( yactdate1(5:6) , '(I2.2)' ) imonth
  WRITE ( yactdate1(7:8) , '(I2.2)' ) iday
  WRITE ( yactdate1(9:10), '(I2.2)' ) ihour
  IF (LEN(TRIM(ystartdate)) == 14) THEN
    yactdate1(11:14) = ystartdate(11:14)
    write(*,'(A14)') yactdate1
  ELSE
    write(*,'(A10)') yactdate1(1:10)
  ENDIF

!.... 
  CASE (2)   !  365 days per year

  monthsum(1) =  0
  DO m =  2 , 13
    monthsum(m) =  monthsum(m-1) + month(m-1)
  enddo

! Determine how many hours have passed in this year
  iyyhours = (idd*24) + monthsum(imm)*24 + (ihh-24)
  iyyhours = iyyhours + hadd
! Take turning of the year into account
    IF (iyyhours < 0) THEN
      iyear    = iyy
      DO WHILE (iyyhours >= 8760)
       iyyhours = iyyhours - 8760
       iyear=iyear+1
       monthsum(1) =  0
       DO m =  2 , 13
           monthsum(m) =  monthsum(m-1) + month(m-1)
       ENDDO
      ENDDO
    ELSE IF (iyyhours >= 8760) THEN
      ! Take also into account if the run lasts
      ! for several years
      iyear    = iyy
      DO WHILE (iyyhours >= 8760)
       iyyhours = iyyhours - 8760
       iyear=iyear+1
       monthsum(1) =  0
       DO m =  2 , 13
           monthsum(m) =  monthsum(m-1) + month(m-1)
       ENDDO
      ENDDO
    ELSE
      iyear    =   iyy
    ENDIF

! Determine the actual date from iyyhours
  m        = 1
  immhours = iyyhours
  DO WHILE (immhours >= 0)
    m        = m+1
    immhours = iyyhours - monthsum(m) * 24
  ENDDO
  imonth   = m-1
  immhours = iyyhours - monthsum(imonth)*24
  iday     = immhours/24 + 1
  ihour    = MOD(immhours,24)
  iweek    = MOD(monthsum(imonth) + iday + (iyear-1981)+(iyear-1981)/4+2 , 7) + 1

  WRITE ( yactdate1(1:4) , '(I4.4)' ) iyear
  WRITE ( yactdate1(5:6) , '(I2.2)' ) imonth
  WRITE ( yactdate1(7:8) , '(I2.2)' ) iday
  WRITE ( yactdate1(9:10), '(I2.2)' ) ihour
  IF (LEN(TRIM(ystartdate)) == 14) THEN
    yactdate1(11:14) = ystartdate(11:14)
    write(*,'(A14)') yactdate1
  ELSE
    write(*,'(A10)') yactdate1(1:10)
  ENDIF


  END SELECT

END SUBROUTINE add_hours
