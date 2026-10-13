MODULE  mo_utilities


!
!-------------------------------------------------------------------------------
!
! Description:
!    Define different kinds of precision
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

USE mo_kind
USE netcdf

IMPLICIT NONE

! Interface Blocks
  INTERFACE get_argument
    MODULE PROCEDURE                          &
      get_argument_Character,                 &
      get_argument_Integer,                   &
      get_argument_Logical,                   &
      get_argument_Real,                      &
      get_argument_Real8                      
  END INTERFACE

!==============================================================================

CONTAINS

!==============================================================================

!******************************************************************************
!******************************************************************************

SUBROUTINE handle_error(status)
  INTEGER, INTENT ( in) :: status 
  IF (status /= nf90_noerr) THEN
    PRINT *, "ERROR: ",TRIM(nf90_strerror(status))
    CALL EXIT (1)
  ENDIF
END SUBROUTINE handle_error


!******************************************************************************
!******************************************************************************

!------------------------------------------------------------------------------

SUBROUTINE  rot2geo (rotlat, rotlon, polphi, pollam, polgam, lat, lon)

!------------------------------------------------------------------------------
!
! Description:
!   This function converts rotated coordinates into geographic coordinates
!
! Method:
!   Transformation formulas for converting between these two systems.
!
! Modules used:    NONE
!
!------------------------------------------------------------------------------

!------------------------------------------------------------------------------
!
! Declarations:
!
!------------------------------------------------------------------------------

! Parameter list:
REAL (KIND=wp), INTENT (IN)      ::        &
  polphi,   & ! latitude of the rotated north pole
  pollam,   & ! longitude of the rotated north pole
  rotlat,   & ! latitude in the rotated system
  rotlon      ! longitude in the rotated system

REAL (KIND=wp), INTENT (IN)      ::        &
  polgam      ! latitude of the rotated north pole

REAL (KIND=wp), INTENT (OUT)       ::        &
  lon, lat      ! 

! Local variables
REAL   (KIND=wp)                 ::        &
  zsinpol, zcospol, zlampol, zphis, zrlas, zarg, zarg1, zarg2, zgam

REAL   (KIND=wp)                ::        &
  zrpi18 = 57.2957795_wp,   & !
  zpir18 = 0.0174532925_wp

!------------------------------------------------------------------------------

!... main part
  zsinpol = SIN (zpir18 * polphi)
  zcospol = COS (zpir18 * polphi)

  zlampol = zpir18 * pollam
  zphis   = zpir18 * rotlat
  IF (rotlon > 180.0_wp) THEN
    zrlas = rotlon - 360.0_wp
  ELSE
    zrlas = rotlon
  ENDIF
  zrlas   = zpir18 * zrlas

  IF ( polgam /= 0.0_wp ) THEN
    zgam    = zpir18 * polgam
    zarg  = zsinpol*SIN (zphis) +                                            &
        zcospol*COS(zphis) * ( COS(zrlas)*COS(zgam) - SIN(zgam)*SIN(zrlas) )
    zarg1   = SIN (zlampol) *                                                &
      (- zsinpol*COS(zphis) * (COS(zrlas)*COS(zgam) - SIN(zrlas)*SIN(zgam))  &
       + zcospol * SIN(zphis))                                               &
    - COS (zlampol)*COS(zphis) * (SIN(zrlas)*COS(zgam) + COS(zrlas)*SIN(zgam))

    zarg2   = COS (zlampol) *                                                &
      (- zsinpol*COS(zphis) * (COS(zrlas)*COS(zgam) - SIN(zrlas)*SIN(zgam))  &
       + zcospol * SIN(zphis))                                               &
    + SIN (zlampol)*COS(zphis) * (SIN(zrlas)*COS(zgam) + COS(zrlas)*SIN(zgam))
  ELSE
    zarg  = zcospol * COS (zphis) * COS (zrlas) + zsinpol * SIN (zphis)
    zarg1   = SIN (zlampol) * (-zsinpol * COS(zrlas) * COS(zphis)  +    &
                                zcospol *              SIN(zphis)) -    &
              COS (zlampol) *             SIN(zrlas) * COS(zphis)
    zarg2   = COS (zlampol) * (-zsinpol * COS(zrlas) * COS(zphis)  +    &
                                zcospol *              SIN(zphis)) +   &
              SIN (zlampol) *             SIN(zrlas) * COS(zphis)
  ENDIF

  IF (zarg2 == 0.0_wp) zarg2 = 1.0E-20_wp

  lon = zrpi18 * ATAN2(zarg1,zarg2)
  lat = zrpi18 * ASIN (zarg)


END SUBROUTINE rot2geo

!******************************************************************************
!******************************************************************************

  SUBROUTINE calc_utc_date (ystartdate, sadd, itype_calendar, yactdate)

!------------------------------------------------------------------------------
!
! Description:
!   This routine determines the actual date of this forecast step.
!
! Method:
!   Using the date of the forecast-start, the number of time steps 
!   already performed and the length of the time steps, the actual
!   date is calculated taking leap-years into consideration.
!   The date is given in three different formats.
!
! Modules used:    NONE
!
!------------------------------------------------------------------------------
  IMPLICIT NONE
 
  INTEGER, PARAMETER       ::                                         &
       ireals    = SELECTED_REAL_KIND (12,200),                       &
       int_dp    = SELECTED_INT_KIND (12)

!
! Input Parameter list:
! ---------------------

  CHARACTER (LEN=14), INTENT(IN)           ::                           &
    ystartdate ! start date of the forecast

  REAL (KIND=ireals)  , INTENT(IN)      ::                           &
    sadd         ! seconds to be added to ystartdate

  INTEGER, INTENT(IN)          ::                &
    itype_calendar ! type of calendar

! Output Parameter list:
! ----------------------

  CHARACTER (LEN=14), INTENT(OUT)          ::                           &
    yactdate  ! actual date in the form   yyyymmddhh[mmss]


! Local variables:
  INTEGER     ::                                       &
    month(12), monthsum(13), ileap, iweek, iy, m,                       &
    idd, imm, iyy, ihh, imi, iss,                                       &
    iday, imonth, iyear, ihour, imin, isec,                             &
    immhours, iyyhours, iyear_hours, inhour, irsec

  REAL (KIND=ireals) :: acthour

  CHARACTER (LEN=3)            :: yweek(7)

! And for computing the amount of seconds of the whole forecast time,
! an 8-Byte INTEGER has to be used. Otherwise the computation fails after
! approx. 68 years!!

  INTEGER (KIND=int_dp) :: insec

!------------ End of header ---------------------------------------------------

! Begin subroutine get_utc_date

DATA         month  / 31 ,  28 ,  31 ,  30 ,  31 ,  30 ,       &
                      31 ,  31 ,  30 ,  31 ,  30 ,  31 /
DATA         yweek  /'MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN' /


! Statementfunction: ileap(yy) = 0:  no leap year, 
!                    ileap(yy) = 1:  leap year
! corrected version for Gregorian / Proleptic calendar
! by A. Dobler, CLM Community
  ileap (iy) = IABS( MOD(iy,  4) -   4) /   4  & ! every       4 years is a leapyear
              -IABS( MOD(iy,100) - 100) / 100  & ! every     100 years is no leapyear
              +IABS( MOD(iy,400) - 400) / 400    ! but every 400 years is a leapyear

! Divide ystartdate in day, month, year and hour
! and since version 4.24: also in minutes and seconds
! and calculate the sums of days from the beginning of the year to the 
! end of the months
  IF (LEN(TRIM(ystartdate)) == 10) THEN
    READ ( ystartdate, '(I4,3I2)' ) iyy, imm, idd, ihh
    imi = 0
    iss = 0
  ELSE
    READ ( ystartdate, '(I4,5I2)' ) iyy, imm, idd, ihh, imi, iss
  ENDIF

  IF     (itype_calendar == 0) THEN
    month (2)    = 28 + ileap (iyy)
    monthsum(1) =  0
    DO m =  2 , 13
      monthsum(m) =  monthsum(m-1) + month(m-1)
    enddo
  ELSEIF (itype_calendar == 1) THEN
    monthsum(1) =  0
    DO m =  2 , 13
      monthsum(m) =  monthsum(m-1) + 30
    enddo
  ELSEIF (itype_calendar == 2) THEN
    monthsum(1) =  0
    DO m =  2 , 13
      monthsum(m) =  monthsum(m-1) + month(m-1)
    enddo
  ENDIF

! Determine how many hours have passed in this year
! iyyhours counts to the start of the forecast (if it is a full hour)
! or to the full hour before start of the forecast
  iyyhours = (idd*24) + monthsum(imm)*24 + (ihh-24)

! insec adds the seconds between full hour before start of the forecast and the
! start of the forecast (if any) + the forecast length in seconds
  insec = INT(sadd, int_dp)
  
! inhour is the same in (full) hours
  IF (insec >= 0) THEN
     inhour = INT(insec/3600_int_dp)
  ELSE
     inhour = INT(FLOOR(REAL(insec,ireals)/3600_ireals))
  ENDIF
  iyyhours = iyyhours + inhour

! Take turning of the year into account
  IF     (itype_calendar == 0) THEN
    iyear_hours = 8760 + ileap(iyy)*24.0_ireals
  ELSEIF (itype_calendar == 1) THEN
    iyear_hours = 8640
  ELSEIF (itype_calendar == 2) THEN
    iyear_hours = 8760
  ENDIF

  IF (iyyhours < 0) THEN
    iyear    = iyy-1
    IF     (itype_calendar == 0) THEN
      iyyhours = 8760 + ileap(iyear)*24.0_ireals + iyyhours
    ELSEIF (itype_calendar == 1) THEN
      iyyhours = 8640                            + iyyhours
    ELSEIF (itype_calendar == 2) THEN
      iyyhours = 8760                            + iyyhours
    ENDIF
  ELSE IF (iyyhours >= iyear_hours) THEN
    ! Take also into account if the run lasts for several years
    iyear    = iyy
    IF     (itype_calendar == 0) THEN
      iyear_hours = 8760 + ileap(iyear)*24.0_ireals
    ELSEIF (itype_calendar == 1) THEN
      iyear_hours = 8640
    ELSEIF (itype_calendar == 2) THEN
      iyear_hours = 8760
    ENDIF

    DO WHILE (iyyhours >= iyear_hours)
      iyyhours = iyyhours - iyear_hours
      iyear=iyear+1
      IF     (itype_calendar == 0) THEN
        iyear_hours = 8760 + ileap(iyear)*24.0_ireals
      ELSEIF (itype_calendar == 1) THEN
        iyear_hours = 8640
      ELSEIF (itype_calendar == 2) THEN
        iyear_hours = 8760
      ENDIF
    ENDDO
  ELSE
    iyear    =   iyy
  ENDIF

  ! calculate monthsum for actual year
  IF     (itype_calendar == 0) THEN
    month (2)    = 28 + ileap (iyear)
    monthsum(1) =  0
    DO m =  2 , 13
      monthsum(m) =  monthsum(m-1) + month(m-1)
    enddo
  ELSEIF (itype_calendar == 1) THEN
    monthsum(1) =  0
    DO m =  2 , 13
      monthsum(m) =  monthsum(m-1) + 30
    enddo
  ELSEIF (itype_calendar == 2) THEN
    monthsum(1) =  0
    DO m =  2 , 13
      monthsum(m) =  monthsum(m-1) + month(m-1)
    enddo
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

! irsec are the seconds left between the last full hour and the actual time
  irsec    = INT(MODULO(insec,  3600_int_dp))
  imin     = INT(irsec/60)
  isec     = MODULO(irsec,  60)
! add the time between the last full hour and the actual time
  acthour  = REAL (ihour, ireals) +  REAL (irsec, ireals) / 3600.0_ireals
  ihour    = INT(acthour)

  WRITE ( yactdate(1:4)  , '(I4.4)' ) iyear
  WRITE ( yactdate(5:6)  , '(I2.2)' ) imonth
  WRITE ( yactdate(7:8)  , '(I2.2)' ) iday
  WRITE ( yactdate(9:10) , '(I2.2)' ) ihour

  IF (LEN(TRIM(ystartdate)) == 14) THEN
    WRITE ( yactdate(11:12), '(I2.2)' ) imin
    WRITE ( yactdate(13:14), '(I2.2)' ) isec
  ENDIF

END SUBROUTINE calc_utc_date

!******************************************************************************
!******************************************************************************

SUBROUTINE calc_seconds (ystartdate, yenddate, itype_calendar, seconds)

!-------------------------------------------------------------------------------
!
! Description:
!   This routine determines the number of seconds between two dates
!
!
! Modules used:    NONE
!
!-------------------------------------------------------------------------------

  IMPLICIT NONE

  INTEGER, PARAMETER       ::                                         &
       int_dp    = SELECTED_INT_KIND (12)
!
! Input Parameter list:
! ---------------------

  CHARACTER (LEN=14)           ::                           &
    ystartdate, & ! start date of the forecast
    yenddate      ! end date of the forecast

  INTEGER, INTENT(IN)          ::                &
    itype_calendar ! type of calendar

! Output Parameter list:
! ---------------------

  INTEGER (KIND=int_dp) :: &
    seconds

! Local variables:
  INTEGER      ::                                       &
    i, iy, &
    month(12), ileap, year_s, month_s, day_s, hour_s, min_s, sec_s, &
                      year_e, month_e, day_e, hour_e, min_e, sec_e, &
                      full_years, full_months, full_days, hours

!------------ End of header ----------------------------------------------------

! Begin subroutine calc_hours

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
        IF (full_days > 1) THEN
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
      IF (full_months > 1) THEN
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

  CASE (1)   !  360 days per year

! year_s == year_e
    IF (year_s == year_e) THEN
      IF (month_e > month_s + 1) THEN
        hours = hours + (month_e - month_s - 1) * 720
      ENDIF
      IF (month_e > month_s) THEN
        full_days = 30 - day_s
        IF (full_days > 1) THEN
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
        IF (full_days > 1) THEN
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
      IF (full_months > 1) THEN
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

    seconds = INT(hours * 3600.,int_dp)
  
    IF (LEN(TRIM(ystartdate)) == 14) THEN
      READ ( ystartdate, '(I4,5I2)' ) year_s, month_s, day_s, hour_s, min_s, sec_s
      READ ( yenddate, '(I4,5I2)' ) year_e, month_e, day_e, hour_e, min_e, sec_e
      sec_s = min_s * 60 + sec_s
      sec_e = min_e * 60 + sec_e
      seconds = seconds + sec_e - sec_s
    ENDIF
    
  
END SUBROUTINE calc_seconds

!******************************************************************************
!******************************************************************************

SUBROUTINE calc_hours (ystartdate, yenddate, itype_calendar, hours)

!-------------------------------------------------------------------------------
!
! Description:
!   This routine determines the number of hours between two dates
!
!
! Modules used:    NONE
!
!-------------------------------------------------------------------------------

  IMPLICIT NONE
!
! Input Parameter list:
! ---------------------

  CHARACTER (LEN=10)           ::                           &
    ystartdate, & ! start date of the forecast
    yenddate      ! end date of the forecast

  INTEGER, INTENT(IN)          ::                &
    itype_calendar ! type of calendar

! Output Parameter list:
! ---------------------

  INTEGER :: &
    hours

! Local variables:
  INTEGER      ::                                       &
    i, iy, &
    month(12), ileap, year_s, month_s, day_s, hour_s, year_e, month_e, day_e, hour_e, &
    full_years, full_months, full_days

!------------ End of header ----------------------------------------------------

! Begin subroutine calc_hours

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
  
  IF (itype_calendar == 1) THEN

! year_s == year_e
    IF (year_s == year_e) THEN
      IF (month_e > month_s + 1) THEN
        hours = hours + (month_e - month_s - 1) * 720
      ENDIF
      IF (month_e > month_s) THEN
        full_days = 30 - day_s
        IF (full_days > 1) THEN
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
  
  ELSE  ! standard calendar
  
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
        IF (full_days > 1) THEN
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
      IF (full_months > 1) THEN
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
    
 ENDIF
  
END SUBROUTINE calc_hours
!==============================================================================

!******************************************************************************
!******************************************************************************

!==============================================================================
!+ Defines all subroutines for the generic routine get_argument
!------------------------------------------------------------------------------
!
! SUBROUTINE get_argument (iposition, argument)
!
!------------------------------------------------------------------------------

! Following are the different subroutines

!------------------------------------------------------------------------------

!+ Subroutine for Character argument

SUBROUTINE get_argument_Character (iposition, argument)  

!------------------------------------------------------------------------------
!
! Declarations must be of the form:
! <type> <VariableName> ! Description/ purpose of variable
!
  INTEGER, INTENT(IN)   :: &
     iposition          ! position of the argument
  CHARACTER (LEN=*), INTENT(OUT) :: &
     argument        ! argument

!------------------------------------------------------------------------------
! local variables

   CHARACTER (LEN=250) :: &
     carg        ! argument

!- End of header
!------------------------------------------------------------------------------

   CALL GET_COMMAND_ARGUMENT(iposition, carg)
   argument = TRIM(carg)

END SUBROUTINE get_argument_Character

!------------------------------------------------------------------------------

!+ Subroutine for Integer argument

SUBROUTINE get_argument_Integer (iposition, argument)  

!------------------------------------------------------------------------------
!
! Declarations must be of the form:
! <type> <VariableName> ! Description/ purpose of variable
!
  INTEGER, INTENT(IN)   :: &
     iposition          ! position of the argument
  INTEGER, INTENT(OUT) :: &
     argument        ! argument

!------------------------------------------------------------------------------
! local variables

   CHARACTER (LEN=250) :: &
     carg        ! argument

!- End of header
!------------------------------------------------------------------------------

   CALL GET_COMMAND_ARGUMENT(iposition, carg)
   READ(carg,*) argument

END SUBROUTINE get_argument_Integer

!------------------------------------------------------------------------------

!+ Subroutine for Logical argument

SUBROUTINE get_argument_Logical (iposition, argument)  

!------------------------------------------------------------------------------
!
! Declarations must be of the form:
! <type> <VariableName> ! Description/ purpose of variable
!
  INTEGER, INTENT(IN)   :: &
     iposition          ! position of the argument
  LOGICAL, INTENT(OUT) :: &
     argument        ! argument

!------------------------------------------------------------------------------
! local variables

   CHARACTER (LEN=250) :: &
     carg        ! argument

!- End of header
!------------------------------------------------------------------------------

   CALL GET_COMMAND_ARGUMENT(iposition, carg)
   READ(carg,*) argument

END SUBROUTINE get_argument_Logical

!------------------------------------------------------------------------------

!+ Subroutine for Real argument

SUBROUTINE get_argument_Real (iposition, argument)  

!------------------------------------------------------------------------------
!
! Declarations must be of the form:
! <type> <VariableName> ! Description/ purpose of variable
!
  INTEGER, INTENT(IN)   :: &
     iposition          ! position of the argument
  REAL, INTENT(OUT) :: &
     argument        ! argument

!------------------------------------------------------------------------------
! local variables

   CHARACTER (LEN=250) :: &
     carg        ! argument

!- End of header
!------------------------------------------------------------------------------

   CALL GET_COMMAND_ARGUMENT(iposition, carg)
   READ(carg,*) argument

END SUBROUTINE get_argument_Real

!+ Subroutine for Real8 argument

SUBROUTINE get_argument_Real8 (iposition, argument)  

!------------------------------------------------------------------------------
!
! Declarations must be of the form:
! <type> <VariableName> ! Description/ purpose of variable
!
  INTEGER, INTENT(IN)   :: &
     iposition          ! position of the argument
  REAL (KIND=wp), INTENT(OUT) :: &
     argument        ! argument

!------------------------------------------------------------------------------
! local variables

   CHARACTER (LEN=250) :: &
     carg        ! argument

!- End of header
!------------------------------------------------------------------------------

   CALL GET_COMMAND_ARGUMENT(iposition, carg)
   READ(carg,*) argument

END SUBROUTINE get_argument_Real8

!==============================================================================


END MODULE mo_utilities
