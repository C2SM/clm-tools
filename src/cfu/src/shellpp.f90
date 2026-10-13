SUBROUTINE shellpp (infile, outfile, nnames, name)

!-------------------------------------------------------------------------------
!
! Description:
!
!   "precompiles" a shell script.
!
!   Usage:
!     shellpp <input file> <output file>  <name1> [ <name2> <name3> ...]
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
  
! Input Parameter list:
! ---------------------

  INTEGER :: nnames
  
  CHARACTER (LEN=*) ::     &
             infile,       &  ! input file with PP directives
             outfile,      &  ! output file without PP directives
             name(nnames)     ! name in the "#idfef name"

! Local variables:
! ------------------------------------
  
  CHARACTER (LEN=1000), ALLOCATABLE :: line(:)
  CHARACTER (LEN=1000) line_clause
  
  CHARACTER (LEN=11) delline
  
  INTEGER :: i, j, ierr, icheck, nlines_in, nlines_out
  LOGICAL :: lwrite

!------------ End of header ----------------------------------------------------
  
  delline="#0000000000"

  OPEN (1,FILE=infile,FORM='FORMATTED',IOSTAT=ierr)
  IF (ierr /= 0) THEN
    PRINT *,'Error: file ',TRIM(infile),' cannot be opened'
    STOP
  ENDIF

  OPEN (2,FILE=outfile,FORM='FORMATTED',IOSTAT=ierr)

!... count number of input lines
  nlines_in=0
  DO
    READ (1,'(A)',IOSTAT=ierr) 
    IF (ierr /= 0) exit
    nlines_in = nlines_in + 1
  ENDDO
  REWIND (1)
  
  ALLOCATE (line(nlines_in))

!... read lines and set delline to the #ifdef and #endif lines of the first name
    DO j = 1, nlines_in
      READ (1,'(A)',IOSTAT=ierr) line(j)
    ENDDO

!... set delline for the #else part of existing names
  DO i = 1, nnames
    lwrite = .TRUE.
    DO j = 1, nlines_in
 
      IF (line(j)(1:5) == '#else' .AND. index(line(j), TRIM(name(i))) /= 0) THEN
        lwrite = .FALSE.
      ENDIF
      IF (line(j)(1:6) == '#endif' .AND. index(line(j), TRIM(name(i))) /= 0) THEN
         lwrite = .TRUE.
      ENDIF
      IF (.NOT. lwrite) THEN
        line(j) = delline
      ENDIF

    ENDDO
  ENDDO

!... set delline to the #ifdef and #endif of existing names
  DO i = 1, nnames
    DO j = 1, nlines_in
 
      IF (line(j)(1:6) == '#ifdef' .AND. index(line(j), TRIM(name(i))) /= 0) line(j) = delline
      IF (line(j)(1:6) == '#endif' .AND. index(line(j), TRIM(name(i))) /= 0) line(j) = delline

    ENDDO
  ENDDO

!... set delline for rest of the lines between #ifdef and #else which are not in the names array
   lwrite=.TRUE.
   DO j = 1, nlines_in
 
     IF (line(j)(1:6) == '#ifdef' .AND. LWRITE) THEN
       lwrite=.FALSE.
       line_clause = TRIM(ADJUSTL(line(j)(7:)))
     ENDIF
     IF (line(j)(1:5) == '#else' .AND. index(line(j), TRIM(line_clause)) /= 0) THEN
       line(j) = delline
       lwrite=.TRUE.
     ENDIF
     IF (line(j)(1:6) == '#endif' .AND. index(line(j), TRIM(line_clause)) /= 0) THEN
       line(j) = delline
       lwrite=.TRUE.
     ENDIF
     IF (.NOT. lwrite)  line(j) = delline

  ENDDO

!... shift lines to eliminate the delline
  nlines_out = nlines_in
  DO j = 1, nlines_in
    IF (line(j)(1:11) == delline ) THEN
      nlines_out = nlines_out -1
    ELSE
      line(j-nlines_in+nlines_out) = line(j)
    ENDIF
  ENDDO

!... write the cleaned lines
  DO j = 1,nlines_out
    WRITE (2,'(A)') TRIM(line(j))
  ENDDO

END SUBROUTINE shellpp
