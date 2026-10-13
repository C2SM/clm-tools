MODULE mo_utils

!
!-------------------------------------------------------------------------------
!
! Description:
!   - error handling
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

IMPLICIT NONE

contains
!=============================================================================

SUBROUTINE handle_err(status,text)
  INTEGER, INTENT (in)        :: status
  CHARACTER(len=*), INTENT(in) :: text
  IF (status /= NF90_NOERR) THEN
     PRINT *, "NETCDF-ERROR in correct_cf at : ",&
          TRIM(text),' :: ', &
          TRIM(nf90_strerror(status))
     ! stop "Stopped"
  ENDIF
END SUBROUTINE handle_err

!=============================================================================

END MODULE mo_utils
