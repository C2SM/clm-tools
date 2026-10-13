SUBROUTINE get_hours (ystartdate, yenddate, itype_calendar)

!-------------------------------------------------------------------------------
!
! Description:
!   This routine determines the number of hours between two dates
!
!
! Output on standard device: number of hours
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
    ystartdate, & ! start date of the forecast
    yenddate      ! end date of the forecast

  INTEGER, INTENT(IN) :: &
    itype_calendar  ! type of calendar 
                    ! 0 = standard calendar
                    ! 1 = climatological calendar (360 days per year)
                    ! 2 = 365 days per year

! Local variables:
  INTEGER      ::                                       &
    i, iy, iargc, &
    month(12), ileap, year_s, month_s, day_s, hour_s, year_e, month_e, day_e, hour_e, &
    full_years, full_months, full_days, hours
  CHARACTER (LEN=200)          :: chours

!------------ End of header ----------------------------------------------------

! Begin subroutine get_utc_date

DATA         month  / 31 ,  28 ,  31 ,  30 ,  31 ,  30 ,       &
                      31 ,  31 ,  30 ,  31 ,  30 ,  31 /

! Statementfunction: ileap(yy) = 0:  no leap year, 
!                    ileap(yy) = 1:  leap year
  ileap (iy) = IABS( MOD(iy,  4) -   4) /   4  & ! every       4 years is a leapyear
              -IABS( MOD(iy,100) - 100) / 100  & ! every     100 years is no leapyear
              +IABS( MOD(iy,400) - 400) / 400    ! but every 400 years is a leapyear


! Divide ystartdate in day, month, year and hour
! and calculate the sums of days from the beginning of the year to the 
! end of the months
  READ ( ystartdate, '(I4,3I2)' ) year_s, month_s, day_s, hour_s
  READ ( yenddate, '(I4,3I2)' ) year_e, month_e, day_e, hour_e

  hours = 0
  full_years = year_e - year_s
  
  SELECT CASE (itype_calendar)

  CASE (0)   !  Standard year
  
! year_s == year_e
    IF (year_s == year_e) THEN
      month(2) = 28 + ileap(year_s)
      IF (month_e > month_s + 1) THEN
        DO i = month_s+1, month_e-1
          hours = hours + month(i) * 24
        ENDDO
      ENDIF
      IF (month_e > month_s) THEN
        full_days = month(month_s) - day_s
        IF (full_days >= 1) THEN
          hours = hours + full_days * 24
        ENDIF
        hours = hours + 24 - hour_s
        full_days = day_e - 1
        IF (full_days > 0) THEN
          hours = hours + full_days * 24
        ENDIF
        hours = hours + hour_e
      ELSE
        full_days = day_e - day_s - 1
        IF (full_days > 0) THEN
          hours = hours + full_days * 24
        ENDIF
        IF (day_e > day_s) THEN
          hours = hours + 24 - hour_s
          hours = hours + hour_e
        ELSE
          hours = hours + hour_e - hour_s
        ENDIF
      ENDIF

    ELSE
  ! year_s < year_e
    ! full years
      IF (full_years > 1) THEN
        DO i = year_s+1, year_e-1
          hours = hours + (365 + ileap(i)) * 24
        ENDDO
      ENDIF
    ! start year
      month(2) = 28 + ileap(year_s)
    ! full months
      full_months = 12 - month_s
      IF (full_months > 0) THEN
        DO i = month_s+1, 12
          hours = hours + month(i) * 24
        ENDDO
      ENDIF
    ! full days
      full_days = month(month_s) - day_s
      IF (full_days > 0) THEN
        hours = hours + full_days * 24
      ENDIF
    ! hours left
      hours = hours + 24 - hour_s

    ! end year
    ! full months
      IF (month_e > 1) THEN
        month(2) = 28 + ileap(year_e)
        DO i = 1, month_e-1
          hours = hours + month(i) * 24
        ENDDO
      ENDIF
    ! full days
      IF (day_e > 1) THEN
        hours = hours + (day_e - 1) * 24
      ENDIF
    ! hours left
      hours = hours + hour_e
      
    ENDIF

!....
  CASE (1)   !  360 days per year

! year_s == year_e
    IF (year_s == year_e) THEN
      IF (month_e > month_s + 1) THEN
        hours = hours + (month_e - month_s - 1) * 720
      ENDIF
      IF (month_e > month_s) THEN
        full_days = 30 - day_s
        IF (full_days >= 1) THEN
          hours = hours + full_days * 24
        ENDIF
        hours = hours + 24 - hour_s
        full_days = day_e - 1
        IF (full_days > 0) THEN
          hours = hours + full_days * 24
        ENDIF
        hours = hours + hour_e
      ELSE
        full_days = day_e - day_s - 1
        IF (full_days > 0) THEN
          hours = hours + full_days * 24
        ENDIF
        IF (day_e > day_s) THEN
          hours = hours + 24 - hour_s
          hours = hours + hour_e
        ELSE
          hours = hours + hour_e - hour_s
        ENDIF
      ENDIF

    ELSE
    
    ! year_s < year_e
    ! full years
      IF (full_years > 1) THEN
        hours = hours + (full_years-1) * 8640
      ENDIF
    ! start year
    ! full months
      full_months = 12 - month_s
      IF (full_months > 0) THEN
        hours = hours + full_months * 720
      ENDIF
    ! full days
      full_days = 30 - day_s
      IF (full_days > 0) THEN
        hours = hours + full_days * 24
      ENDIF
    ! hours left
        hours = hours + 24 - hour_s
    ! end year
    ! full_months
      IF (month_e > 1) THEN
        hours = hours + (month_e - 1) * 720
      ENDIF
    ! full_days
      IF (day_e > 1) THEN
        hours = hours + (day_e - 1) * 24
      ENDIF
    ! hours left
      hours = hours + hour_e
      
    ENDIF
  
!....
  CASE (2)   !  365 days per year
  
! year_s == year_e
    IF (year_s == year_e) THEN
      IF (month_e > month_s + 1) THEN
        DO i = month_s+1, month_e-1
          hours = hours + month(i) * 24
        ENDDO
      ENDIF
      IF (month_e > month_s) THEN
        full_days = month(month_s) - day_s
        IF (full_days >= 1) THEN
          hours = hours + full_days * 24
        ENDIF
        hours = hours + 24 - hour_s
        full_days = day_e - 1
        IF (full_days > 0) THEN
          hours = hours + full_days * 24
        ENDIF
        hours = hours + hour_e
      ELSE
        full_days = day_e - day_s - 1
        IF (full_days > 0) THEN
          hours = hours + full_days * 24
        ENDIF
        IF (day_e > day_s) THEN
          hours = hours + 24 - hour_s
          hours = hours + hour_e
        ELSE
          hours = hours + hour_e - hour_s
        ENDIF
      ENDIF

    ELSE
  ! year_s < year_e
    ! full years
      IF (full_years > 1) THEN
        DO i = year_s+1, year_e-1
          hours = hours + 8760
        ENDDO
      ENDIF
    ! start year
    ! full months
      full_months = 12 - month_s
      IF (full_months > 0) THEN
        DO i = month_s+1, 12
          hours = hours + month(i) * 24
        ENDDO
      ENDIF
    ! full days
      full_days = month(month_s) - day_s
      IF (full_days > 0) THEN
        hours = hours + full_days * 24
      ENDIF
    ! hours left
      hours = hours + 24 - hour_s

    ! end year
    ! full months
      IF (month_e > 1) THEN
        DO i = 1, month_e-1
          hours = hours + month(i) * 24
        ENDDO
      ENDIF
    ! full days
      IF (day_e > 1) THEN
        hours = hours + (day_e - 1) * 24
      ENDIF
    ! hours left
      hours = hours + hour_e
      
    ENDIF
   
  END SELECT
  
  WRITE(chours,*) hours
  WRITE(*,'(A)') TRIM(ADJUSTL(chours))


END SUBROUTINE get_hours

