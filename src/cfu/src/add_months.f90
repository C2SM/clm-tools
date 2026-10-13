SUBROUTINE add_months (ystartdate, madd)

!-------------------------------------------------------------------------------
!
! Description:
!   This program adds a number of months to a date
!   YYYYMMDDHH[mmss](new) = YYYMMDDHH[mmss](old) + months
!
!   Usage:
!     add_hours <yyyymmddhh[mmss]> <months>
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

  IMPLICIT NONE
!
! Input Parameter list:
! ---------------------

  CHARACTER (LEN=14)  , INTENT(IN)          ::         &
    ystartdate    ! start date of the forecast

  INTEGER, INTENT(IN) :: &
    madd       ! months to be added to ystartdate

! Parameter written to standard output
! ------------------------------------

  CHARACTER (LEN=14)          ::                           &
    yactdate1  ! actual date in the form   yyyymmddhh[mmss]


! Local variables:
! ------------------------------------

  INTEGER      ::                                       &
    nmonths, rest_months, iargc, &
    year_s, month_s, day_s, hour_s, year_e, month_e, day_e, hour_e, &
    full_years


!------------ End of header ----------------------------------------------------

! Begin subroutine add_months

  READ ( ystartdate, '(I4,3I2)' ) year_s, month_s, day_s, hour_s

  nmonths = madd
  month_e = month_s + nmonths
!  WRITE(*,*) madd, nmonths, month_s, month_e
  IF (month_e <= 12) THEN
    year_e = year_s
!    WRITE(*,*) year_s, year_e
    day_e  = day_s
    hour_e = hour_s
  ELSE
    nmonths = nmonths - 12 + month_s
    full_years = nmonths / 12
    rest_months = nmonths - full_years * 12
    year_e = year_s + full_years + 1
    month_e = rest_months
    IF (month_e == 0) month_e = 12
    day_e  = day_s
    hour_e = hour_s
  ENDIF

  WRITE(yactdate1,'(I4.4,3I2.2)') year_e, month_e, day_e, hour_e
  IF (LEN(TRIM(ystartdate)) == 14) THEN
    yactdate1(11:14) = ystartdate(11:14)
    WRITE(*,'(A14)') yactdate1
  ELSE
    WRITE(*,'(A10)') yactdate1(1:10)
  ENDIF
 
END SUBROUTINE add_months
