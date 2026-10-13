SUBROUTINE p2sec (Pin)

!-------------------------------------------------------------------------------
!
! Description:
!   Converts ISO 8601 duration in the form PThhHmmMssS into seconds
!
!   Usage:
!     cfu p2sec <PThhHmmMssS>
!
!   The result is written to standard output
!
!.....................................................
! Copyright 2021 Helmholtz-Zentrum Hereon
! Licensed under the GNU License, Version 3.0
! (https://www.gnu.org/licenses/gpl-3.0.html)
! Author(s): Burkhardt Rockel (Hereon)
!.....................................................
!
!-------------------------------------------------------------------------------
!

  USE mo_kind

  IMPLICIT NONE

!... Input
  CHARACTER (LEN=*) :: Pin

!... Output
  INTEGER (kind=int8) :: seconds
  
!... Other variables
  INTEGER :: &
    i, j, ip, it

  INTEGER (kind=int8) :: &
    ipart, ilen

  CHARACTER (LEN=50) :: &
    P, Ppart

!... Program start
  
  P = Pin
  seconds = 0

  i = INDEX(P,'PT')
  IF (i == 0) THEN
    PRINT *, "ERROR: No ISO 8601 duration format starting with PT"
    STOP
  ENDIF

  ! remove PT
  ilen = LEN_TRIM(P)
  P = Pin(3:ilen)

  i = INDEX(P,'H')
  ilen = LEN_TRIM(P)
  IF (i > 0) THEN
    Ppart = P(1:i-1)
    READ (Ppart,*) ipart
    seconds = seconds + ipart * 3600_int8
    P = P(i+1:ilen)
  ENDIF

  i = INDEX(P,'M')
  ilen = LEN_TRIM(P)
  IF (i > 0) THEN
    Ppart = P(1:i-1)
    READ (Ppart,*) ipart
    seconds = seconds + ipart * 60_int8
    P = P(i+1:ilen)
  ENDIF

  i = INDEX(P,'S')
  IF (i > 0) THEN
    Ppart = P(1:i-1)
    READ (Ppart,*) ipart
    seconds = seconds + ipart
  ENDIF
  
  PRINT *, seconds


END SUBROUTINE p2sec

