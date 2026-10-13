MODULE mo_kind

!
!-------------------------------------------------------------------------------
!
! Description:
!    Define different kinds of precision
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

  IMPLICIT NONE

  ! floating point section 

  INTEGER, PARAMETER :: sp = SELECTED_REAL_KIND(6,37)  
  INTEGER, PARAMETER :: dp = SELECTED_REAL_KIND(12,307)
  INTEGER, PARAMETER :: qp = SELECTED_REAL_KIND(33,4931)

  INTEGER, PARAMETER :: wp = dp

  ! integer

  INTEGER, PARAMETER :: int1 = SELECTED_INT_KIND(2)
  INTEGER, PARAMETER :: int2 = SELECTED_INT_KIND(4)
  INTEGER, PARAMETER :: int4 = SELECTED_INT_KIND(9)
  INTEGER, PARAMETER :: int8 = SELECTED_INT_KIND(14)

END MODULE mo_kind
