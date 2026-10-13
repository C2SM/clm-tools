MODULE mo_c2i_data

!
!-------------------------------------------------------------------------------
!
! Description:
!    Preset variables
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

IMPLICIT NONE

!=============================================================================

REAL :: &
  undef = -1.E20

REAL :: &
  default_soil_depth(4)
  
!... soil depth in m (numbers from IFS soil scheme)
 DATA  default_soil_depth / 0.035, 0.175,  0.64 ,  1.945  /

!=============================================================================


END MODULE mo_c2i_data
