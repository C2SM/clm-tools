SUBROUTINE get_prev_date (ystartdate, yinterval, itype_calendar)

!-------------------------------------------------------------------------------
!
! Description:
!   This routine determines the previous date from a given interval
!   
!   Remark: This version only takes monthly intervals
!           itype_calendar is not used in this version
!
!
! Output on standard device: yyyymmddhh
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

  IMPLICIT NONE
!
! Input Parameter list:
! ---------------------

  CHARACTER (LEN=10)           ::                           &
    ystartdate      ! start date

  CHARACTER (LEN=8)           ::                           &
    yinterval       ! time interval

  INTEGER, INTENT(IN) :: &
    itype_calendar  ! type of calendar 
                    ! 0 = standard calendar
                    ! 1 = climatological calendar (360 days per year)
                    ! 2 = 365 days per year

! Local variables:
! ---------------------

  CHARACTER (LEN=10)           ::                           &
    ydate1

  INTEGER      ::                                       &
    ndm, iargc, ileap, &
    year_s, month_s, day_s, hour_s, year_e, month_e, day_e, hour_e, &
    dm, dd, dh, iy

  INTEGER  month(12) 
  
! Statementfunction: ileap(yy) = 0:  no leap year, 
!                    ileap(yy) = 1:  leap year
!  ileap (iy) = IABS( MOD(iy,  4) -   4) /   4  & ! every       4 years is a leapyear
!              -IABS( MOD(iy,100) - 100) / 100  & ! every     100 years is no leapyear
!              +IABS( MOD(iy,400) - 400) / 400    ! but every 400 years is a leapyear

!------------ End of header ----------------------------------------------------

! Begin subroutine get_next_dates

  month =  (/ 31 , 28 , 31 , 30 , 31 , 30 , 31 , 31 , 30 , 31 , 30 , 31 /)

  READ ( ystartdate, '(I4,3I2)' ) year_s, month_s, day_s, hour_s
  READ ( yinterval, '(I2,1X,I2,1X,I2)') dm, dd, dh

!... calculate the first date

!... subtract months
  IF (dm > 12) THEN
    PRINT *, 'Error in get_prev_date : maximum number of months is 12'
    STOP
  ENDIF
  IF (dm == 0) THEN
    year_e  = year_s
    month_e = month_s
    day_e   = day_s
    hour_e  = hour_s
  ELSE
    month_e = month_s - dm
    IF (month_e >= 1) THEN
      year_e = year_s
      day_e  = day_s
      hour_e = hour_s
    ELSE
      year_e = year_s - 1
      month_e = month_e  +12
      day_e  = day_s
      hour_e = hour_s
    ENDIF
  ENDIF

  WRITE ( ydate1(1:4) , '(I4.4)' ) year_e
  WRITE ( ydate1(5:6) , '(I2.2)' ) month_e
  WRITE ( ydate1(7:8) , '(I2.2)' ) day_e
  WRITE ( ydate1(9:10), '(I2.2)' ) hour_e

  write(*,'(A10,A10)') ydate1


END SUBROUTINE get_prev_date
