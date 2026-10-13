PROGRAM cfu

!----------------------------------------------------------------
! The Climate Fortran Utilities (CFU) contain some functions which are neither covered by
!      CDO nor NCO (or only in a complicated way).
!
!.....................................................
! Copyright 2021 Helmholtz-Zentrum Hereon
! Copyright 2010-2020 Helmholtz-Zentrum Geesthacht
! Licensed under the GNU License, Version 3.0
! (https://www.gnu.org/licenses/gpl-3.0.html)
! Author(s): Burkhardt Rockel (Hereon)
!.....................................................
!
!----------------------------------------------------------------

  USE mo_kind
  USE mo_utilities
  USE mo_create_rotgrid

  IMPLICIT NONE
  
  CHARACTER (LEN=250) :: &
    yinpdir

  CHARACTER (LEN=250) :: &
    yinpfile, youtfile

  CHARACTER (LEN=200) :: &
    att_name

  CHARACTER (LEN=50) :: &
    function_name

  CHARACTER (LEN=50) :: &
    yprefix1, yprefix2, ysuffix, Pin

  CHARACTER (LEN=20) :: &
    yname

  CHARACTER (LEN=20), ALLOCATABLE :: &
    yname_array(:)

  CHARACTER (LEN=14) :: &
    ystartdate, yenddate

  CHARACTER (LEN=14) :: &
    yinterval

  INTEGER :: &
    itype_calendar

  LOGICAL :: &
    lastoutput

  REAL :: &
    hours
  
  REAL (KIND=wp) :: &
      startrlon,    & !
      startrlat,    & ! 
      drlon,        & ! 
      drlat,        & ! 
      pollon,       & ! 
      pollat,       & ! 
      polgam          ! 
 
 INTEGER :: &
      i

 INTEGER :: &
      nnames

 INTEGER :: &
      nrlon,        & ! 
      nrlat           ! 

  INTEGER :: &
    months

  INTEGER :: &
    nbound,             &  ! number of extra boundary pixels (are the same on all sides)
    nudge_zone_width,   &  ! add sponge zone, i.e. number of extra boundary pixels (are the same on all sides)
    Rn,                 &  ! definition of ICON grid
    Bk                     ! definition of ICON grid

  IF (COMMAND_ARGUMENT_COUNT() < 1) THEN
    PRINT *, 'ERROR: invalid number of arguments'
    PRINT *, 'Usage: cfu <function> <function argument 1> <function argument 2> .. <function argument n>'
    CALL cfu_help
    STOP
  ENDIF

  CALL get_argument(1,function_name) 
  
  SELECT CASE (TRIM(function_name))
  CASE ('help')

    CALL cfu_help

  CASE ('add_hours')
  
    IF (COMMAND_ARGUMENT_COUNT() < 3 .OR. COMMAND_ARGUMENT_COUNT() > 4) THEN
      PRINT *, 'ERROR: Invalid number of arguments'
      PRINT *, 'Usage: cfu add_hours <ystartdate> <hours> [<itype_calendar>]' 
      STOP
    ENDIF
  
    CALL get_argument(2,ystartdate)
    CALL get_argument(3,hours)


    IF (COMMAND_ARGUMENT_COUNT() == 3) THEN
      itype_calendar = 0
    ELSE
      CALL get_argument(4,itype_calendar)
    ENDIF

    CALL add_hours (ystartdate, hours, itype_calendar)

  CASE ('add_lonlat')
  
    IF (COMMAND_ARGUMENT_COUNT() /= 2 ) THEN
      PRINT *, 'ERROR: Invalid number of arguments'
      PRINT *, 'Usage: cfu add_lonlat <ncfile>'
      STOP
    ENDIF
  
    CALL get_argument(2,yinpfile)
    CALL add_lonlat (TRIM(yinpfile))

  CASE ('add_months')
  
    IF (COMMAND_ARGUMENT_COUNT() /= 3) THEN
      PRINT *, 'ERROR: Invalid number of arguments'
      PRINT *, 'Usage: cfu add_months <ystartdate> <months>'
      STOP
    ENDIF
  
    CALL get_argument(2,ystartdate)
    CALL get_argument(3,months)

    CALL add_months (ystartdate, months)

  CASE ('add_vertices')
  
    IF (COMMAND_ARGUMENT_COUNT() /= 2) THEN
      PRINT *, 'ERROR: Invalid number of arguments'
      PRINT *, 'Usage: cfu add_vertices <ncfile>'
      STOP
    ENDIF
  
    CALL get_argument(2,yinpfile)

    CALL add_vertices (TRIM(yinpfile))

  CASE ('check_files')
  
    IF (COMMAND_ARGUMENT_COUNT() < 9 .OR. COMMAND_ARGUMENT_COUNT() > 10) THEN
      PRINT *, 'ERROR: Invalid number of arguments'
      PRINT *, 'Usage: cfu check_files <ystartdate> <yenddate> <hh:mm:ss> ', &
               '<prefix1> <prefix2> <suffix> <input directory> <lastoutput> [<itype_calendar>]'
    STOP
    END IF

    CALL get_argument(2,ystartdate)
    CALL get_argument(3,yenddate)
    CALL get_argument(4,yinterval)
    CALL get_argument(5,yprefix1)
    CALL get_argument(6,yprefix2)
    CALL get_argument(7,ysuffix)
    CALL get_argument(8,yinpdir)
    CALL get_argument(9,lastoutput)

    IF (COMMAND_ARGUMENT_COUNT() < 10) THEN
      itype_calendar = 0
    ELSE
      CALL get_argument(10,itype_calendar)
    ENDIF


    CALL check_files (ystartdate, yenddate, yinterval, yprefix1, yprefix2, ysuffix, yinpdir, lastoutput, itype_calendar)
 
  CASE ('check_files_iso')
  
    IF (COMMAND_ARGUMENT_COUNT() < 9 .OR. COMMAND_ARGUMENT_COUNT() > 10) THEN
      PRINT *, 'ERROR: Invalid number of arguments'
      PRINT *, 'Usage: cfu check_files <ystartdate> <yenddate> <hh:mm:ss> ', &
               '<prefix1> <prefix2> <suffix> <input directory> <lastoutput> [<itype_calendar>]'
    STOP
    END IF

    CALL get_argument(2,ystartdate)
    CALL get_argument(3,yenddate)
    CALL get_argument(4,yinterval)
    CALL get_argument(5,yprefix1)
    CALL get_argument(6,yprefix2)
    CALL get_argument(7,ysuffix)
    CALL get_argument(8,yinpdir)
    CALL get_argument(9,lastoutput)

    IF (COMMAND_ARGUMENT_COUNT() < 10) THEN
      itype_calendar = 0
    ELSE
      CALL get_argument(10,itype_calendar)
    ENDIF


    CALL check_files_iso (ystartdate, yenddate, yinterval, yprefix1, yprefix2, ysuffix, yinpdir, lastoutput, itype_calendar)
 
  CASE ('create_rotgrid')
  
    IF (COMMAND_ARGUMENT_COUNT() /= 11) THEN
      PRINT *, 'ERROR: Invalid number of arguments'
      PRINT *, 'Usage: cfu create_rotgrid <startrlon> <startrlat> <drlon> <drlat> <nrlon> <nrlat> <pollon> <pollat> <polgam> <grid file> '
    STOP
    END IF

     CALL get_argument(2,startrlon)
     CALL get_argument(3,startrlat)
     CALL get_argument(4,drlon)
     CALL get_argument(5,drlat)
     CALL get_argument(6,nrlon)
     CALL get_argument(7,nrlat)
     CALL get_argument(8,pollon)
     CALL get_argument(9,pollat)
     CALL get_argument(10,polgam)
     CALL get_argument(11,youtfile)


    CALL create_rotgrid (startrlon, startrlat, drlon, drlat, nrlon, nrlat, pollon, pollat, polgam, youtfile)
 
   CASE ('get_attval')
 
     IF (COMMAND_ARGUMENT_COUNT() /= 4) THEN
       PRINT *, 'ERROR: Invalid number of arguments'
       PRINT *, 'Usage: cfu get_attval <ncfile> <varname> <attribute name>'
       STOP
     ENDIF
  
     CALL get_argument(2, yinpfile)
     CALL get_argument(3, yname)
     CALL get_argument(4, att_name)

     CALL get_attval (yinpfile, yname, att_name)

   CASE ('get_hours')
  
    IF (COMMAND_ARGUMENT_COUNT() < 3 .OR. COMMAND_ARGUMENT_COUNT() > 4) THEN
      PRINT *, 'ERROR: Invalid number of arguments'
      PRINT *, 'Usage: cfu get_hours <ystartdate> <yenddate> [<itype_calendar>]'
      STOP
    ENDIF
  
     CALL get_argument(2,ystartdate)
     CALL get_argument(3,yenddate)


    IF (COMMAND_ARGUMENT_COUNT() == 3) THEN
      itype_calendar = 0
    ELSE
      CALL get_argument(4,itype_calendar)
    ENDIF

    CALL get_hours (ystartdate, yenddate, itype_calendar)

   CASE ('get_next_dates')
  
    IF (COMMAND_ARGUMENT_COUNT() < 3 .OR. COMMAND_ARGUMENT_COUNT() > 4) THEN
      PRINT *, 'ERROR: Invalid number of arguments'
      PRINT *, 'Usage: cfu get_next_dates <ystartdate> <mm:dd:hh[:mm:ss]> [<itype_calendar>]'
      STOP
    ENDIF
  
    CALL get_argument(2,ystartdate)
    CALL get_argument(3,yinterval)


    IF (COMMAND_ARGUMENT_COUNT() == 3) THEN
      itype_calendar = 0
    ELSE
      CALL get_argument(4,itype_calendar)
    ENDIF

    CALL get_next_dates (ystartdate, yinterval, itype_calendar)

   CASE ('get_prev_date')

    IF (COMMAND_ARGUMENT_COUNT() < 3 .OR. COMMAND_ARGUMENT_COUNT() > 4) THEN
      PRINT *, 'ERROR: Invalid number of arguments'
      PRINT *, 'Usage: cfu get_prev_date <ystartdate> <mm:dd:hh[:mm:ss]> [<itype_calendar>]'
      STOP
    ENDIF

    CALL get_argument(2,ystartdate)
    CALL get_argument(3,yinterval)


    IF (COMMAND_ARGUMENT_COUNT() == 3) THEN
      itype_calendar = 0
    ELSE
      CALL get_argument(4,itype_calendar)
    ENDIF

    CALL get_prev_date (ystartdate, yinterval, itype_calendar)

  CASE ('icon_domain')

    IF (COMMAND_ARGUMENT_COUNT() < 2) THEN
      PRINT *, 'ERROR: invalid number of arguments'
      PRINT *, 'Usage: icon_clm_domain <netcdf file> [<nbound> [<nudge_zone_width> <Rn> <Bk>] ]'
      STOP
    ENDIF

    CALL get_argument(2,yinpfile)
    IF (COMMAND_ARGUMENT_COUNT() == 2) THEN
      nbound = 0
      nudge_zone_width = 0
      Rn = 0
      Bk = 0
    ELSE IF (COMMAND_ARGUMENT_COUNT() == 3) THEN
      CALL get_argument(3,nbound)
      nudge_zone_width = 0
      Rn = 0
      Bk = 0
    ELSE IF (COMMAND_ARGUMENT_COUNT() == 6) THEN
      CALL get_argument(3,nbound)
      CALL get_argument(4,nudge_zone_width)
      CALL get_argument(5,Rn)
      CALL get_argument(6,Bk)
    ELSE
      PRINT *, 'ERROR: invalid number of arguments'
      PRINT *, 'Usage: icon_clm_domain <netcdf file> [<nbound> [<nudge_zone_width> <Rn> <Bk>] ]'
      STOP
    ENDIF

    CALL icon_domain (yinpfile, nbound, nudge_zone_width, Rn, Bk)

  CASE ('p2sec')

    IF (COMMAND_ARGUMENT_COUNT() /= 2) THEN
      PRINT *, 'ERROR: Invalid number of arguments'
      PRINT *, 'Usage: cfu p2sec <PThhHmmMssS>'
      STOP
    END IF

    CALL get_argument(2,Pin)
    
    CALL p2sec (TRIM(Pin))


  CASE ('shellpp')

    IF (COMMAND_ARGUMENT_COUNT() < 4) THEN
      PRINT *, 'ERROR: too few number of arguments'
      PRINT *, 'Usage: cfu shellpp  <input file> <output file> <name1> [ <name2> <name3> ...]'
      STOP
    END IF

    CALL get_argument(2,yinpfile)
    CALL get_argument(3,youtfile)
    nnames = COMMAND_ARGUMENT_COUNT() - 3
    ALLOCATE (yname_array(nnames))
    DO i = 1, nnames
      CALL get_argument(i+3,yname_array(i))
    ENDDO
    CALL shellpp (TRIM(yinpfile), TRIM(youtfile), nnames, yname_array)
    DEALLOCATE (yname_array)

  CASE ('tbtimestamp')

   IF (COMMAND_ARGUMENT_COUNT() < 2 .OR. COMMAND_ARGUMENT_COUNT() > 3) THEN
      PRINT *, 'ERROR: Invalid number of arguments'
      PRINT *, 'Usage: cfu tbtimestamp <input file> [<itype_calendar>]'
      STOP
    END IF

    CALL get_argument(2,yinpfile)

    IF (COMMAND_ARGUMENT_COUNT() == 2) THEN
      itype_calendar = 0
    ELSE
      CALL get_argument(3,itype_calendar)
    ENDIF

    CALL tbtimestamp (TRIM(yinpfile), itype_calendar)

  CASE DEFAULT
  
    PRINT *, 'ERROR: illegal function'
    CALL cfu_help
  
  END SELECT

END PROGRAM cfu

SUBROUTINE cfu_help

   IMPLICIT NONE
   
   PRINT *
   PRINT *, 'Valid functions:'
   PRINT *, 'add_hours <ystartdate> <hours> [<itype_calendar>]'
   PRINT *, 'add_lonlat <input file>' 
   PRINT *, 'add_months <ystartdate> <months>'
   PRINT *, 'add_vertices <input file>'
   PRINT *, 'check_files <ystartdate> <yenddate> <hh:mm:ss> ', &
            ' <prefix1> <prefix2> <suffix> <input directory> <lastoutput> [<itype_calendar>]'
   PRINT *, 'check_files_iso <ystartdate> <yenddate> <hh:mm:ss> ', &
            ' <prefix1> <prefix2> <suffix> <input directory> <lastoutput> [<itype_calendar>]'
   PRINT *, 'create_rotgrid <startrlon> <startrlat> <drlon> <drlat> <nrlon> <nrlat> <pollon> <pollat> <polgam> <grid file>'
   PRINT *, 'get_attval <ncfile> <varname> <attribute name>'
   PRINT *, 'get_hours <ystartdate> <yenddate> [<itype_calendar>]'
   PRINT *, 'get_next_dates <ystartdate> <mm:dd:hh[:mm:ss]> [<itype_calendar>]'
   PRINT *, 'get_prev_date <ystartdate> <mm:dd:hh[:mm:ss]> [<itype_calendar>]'
   PRINT *, 'icon_clm_domain <netcdf file> [<nbound> [<nudge_zone_width> <Rn> <Bk>] ]'
   PRINT *, 'p2sec <PThhHmmMssS>'
   PRINT *, 'shellpp <input file> <output file> <name1> [ <name2> <name3> ...]'
   PRINT *, 'tbtimestamp <input file> [<itype_calendar>]'
   PRINT *
   PRINT *, 'ystartdate can have the form yyyymmddhh of yyyymmddhhmmss except for check_files_iso: yyyymmddThhmmss'
 
  
   RETURN

END SUBROUTINE cfu_help
