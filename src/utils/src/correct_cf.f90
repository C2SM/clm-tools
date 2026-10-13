PROGRAM correct_cf

!
!-------------------------------------------------------------------------------
!
! Description:
!    Modify ICON netCDF output files to make them follow the CF-Conventions
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

  USE csv_module
  USE iso_fortran_env, only: wp => real64

  USE mo_utils

  IMPLICIT NONE

  INTEGER, PARAMETER :: dp = selected_real_kind(13)
!  INTEGER, PARAMETER :: wp = dp
  INTEGER, PARAMETER :: nlines_max=500
 
  CHARACTER (LEN=8)   :: hout_inc, operation
  CHARACTER (LEN=250) :: ncfile, mapping_file

  type(csv_file) :: f
  logical :: status_ok
  integer,dimension(:),allocatable :: itypes
  character(len=50),dimension(:),allocatable :: header

  INTEGER :: i, itime, nlines, istatus, izdb, isince, index_suffix
  INTEGER :: ihours, iminutes, iseconds
  INTEGER :: ncid, varid, numdims, dimids(10), idim, varid2, bndsdimid, timevarid, timebndsvarid, timedimid(1), timelen, &
             ncells, ncellsdimid
  CHARACTER (LEN=100) ,DIMENSION(:),ALLOCATABLE :: param_icon, param_clm, param_clm_a, height, &
                     cell_method, standard_name, standard_name_a, units_a
  CHARACTER (LEN=100) :: dimname, timeunits, new_name, long_name
  CHARACTER (LEN=1) :: carg
  REAL (kind=wp) :: dseconds, ztimemul, rheight
  REAL (kind=wp), ALLOCATABLE :: time(:), time_bnds(:,:)
  REAL, ALLOCATABLE :: array2d(:,:)
  REAL :: undef
  

  IF (COMMAND_ARGUMENT_COUNT() < 3) then
    PRINT *, "ERROR: invalid number of arguments"
    PRINT *, "correct_cf <HOUT_INC> <mapping file> <input file> [<operation>] "
    STOP
  ENDIF
  CALL get_command_argument(1, hout_inc)
  CALL get_command_argument(2, mapping_file)
  CALL get_command_argument(3, ncfile)
  IF (COMMAND_ARGUMENT_COUNT() == 4) THEN
    CALL get_command_argument(4, operation)
  ELSE
    operation ='NONE'
  ENDIF
  
!... hout_inc to seconds
  READ(hout_inc,'(I2,A1,I2,A1,I2)') ihours, carg, iminutes, carg, iseconds 
  dseconds = REAL(ihours * 3600) + REAL(iminutes * 60) + REAL(iseconds)

!... read variables and attributes from the mapping file
! read the file
call f%read(TRIM(mapping_file),header_row=1,status_ok=status_ok)

! get the header and type info
call f%get_header(header,status_ok)
call f%variable_types(itypes,status_ok)

! get some data
call f%get(1,param_icon,status_ok)
call f%get(2,param_clm,status_ok)
call f%get(3,param_clm_a,status_ok)
call f%get(4,height,status_ok)
call f%get(5,cell_method,status_ok)
call f%get(6,standard_name,status_ok)
call f%get(7,standard_name_a,status_ok)
call f%get(8,units_a,status_ok)

nlines=SIZE(param_icon)

!  nlines=0
!  DO  i = 1,nlines_max
!    READ (1,*,IOSTAT=istatus) param_clm(i), param_icon(i), height(i), cell_method(i), standard_name(i)
!    IF (istatus /= 0) exit
!      nlines=i
!  ENDDO

  
!... open netCDF file to be corrected
  istatus = nf90_open(TRIM(ncfile),  NF90_WRITE, ncid)
  CALL handle_err(istatus,'nf90_open '//TRIM(ncfile))

  istatus = nf90_inq_dimid(ncid, "ncells", ncellsdimid)
  CALL handle_err(istatus,'nf90_inq_dimid ncells')
  istatus = nf90_inquire_dimension(ncid, ncellsdimid, len=ncells)
  CALL handle_err(istatus,'nf90_inquire_dimension ncellsdimid')
  
  IF (dseconds /= 0_wp) THEN
  !... change time to seconds and create time_bnds variable
    istatus = nf90_inq_varid(ncid, "time", timevarid)
    CALL handle_err(istatus,'nf90_inq_varid time')
    istatus = nf90_inquire_variable(ncid, timevarid, dimids=timedimid)
    CALL handle_err(istatus,'nf90_inquire_variable time')
    istatus = nf90_inquire_dimension(ncid, timedimid(1),len=timelen)
    CALL handle_err(istatus,'nf90_inquire_dimension timedimid')
    ALLOCATE (time(timelen), time_bnds(2,timelen))
    istatus = nf90_get_att(ncid, timevarid, "units", timeunits)
    CALL handle_err(istatus,'nf90_get_att timeunits')
    izdb = index(timeunits,'seconds')
        IF (izdb /= 0) THEN
          ztimemul = 1.0_wp
        ELSE
          izdb = index(timeunits,'minutes')
          IF (izdb /= 0) THEN
            ztimemul = 60.0_wp
          ELSE
            izdb = index(timeunits,'hours')
            IF (izdb /= 0) THEN
              ztimemul = 3600.0_wp
            ELSE
              izdb = index(timeunits,'days')
              IF (izdb /= 0) THEN
                ztimemul = 86400.0_wp
              ELSE
                PRINT *, 'No valid time units found. Must be seconds, minutes, hours or days'
                STOP
              ENDIF
            ENDIF
          ENDIF
        ENDIF
    istatus = nf90_redef(ncid)
    CALL handle_err(istatus,'nf90_redef')
    isince = index(timeunits,'since')
    istatus = nf90_put_att(ncid, timevarid, "units", TRIM('seconds '//timeunits(isince:)))
    CALL handle_err(istatus,'nf90_put_att time units')
    istatus = nf90_put_att(ncid, timevarid, "bounds", "time_bnds")
    CALL handle_err(istatus,'nf90_put_att time bounds')
    istatus = nf90_enddef(ncid)
    CALL handle_err(istatus,'nf90_enddef')
    istatus = nf90_get_var(ncid, timevarid, time)
    CALL handle_err(istatus,'nf90_get_var time')
    DO itime = 1, timelen
      time(itime) = time(itime) * ztimemul
      time_bnds(2,itime) = time(itime)
      time_bnds(1,itime) = time(itime) - dseconds
    ENDDO
    istatus = nf90_redef(ncid)
    CALL handle_err(istatus,'nf90_redef')
    istatus = nf90_inq_dimid(ncid, "bnds", bndsdimid)
    IF (istatus /= nf90_noerr) THEN
      istatus = nf90_def_dim(ncid, "bnds", 2, bndsdimid)
    ENDIF
    CALL handle_err(istatus,'nf90_inq_dimid or nf90_def_dim bnds')
    istatus = nf90_def_var(ncid, "time_bnds", NF90_DOUBLE, dimids=(/ bndsdimid, timedimid(1) /), varid=timebndsvarid)
    CALL handle_err(istatus,'nf90_def_var time_bnds')
    istatus = nf90_put_att(ncid, timebndsvarid, "long_name", "time bounds")
    CALL handle_err(istatus,'nf90_put_att long_name time_bnds')
    istatus = nf90_put_att(ncid, timebndsvarid, "units", TRIM('seconds '//timeunits(isince:)))
    CALL handle_err(istatus,'nf90_put_att units time_bnds')
    istatus = nf90_enddef(ncid)
    CALL handle_err(istatus,'nf90_enddef')
    istatus = nf90_put_var(ncid, timevarid, time)
    CALL handle_err(istatus,'nf90_put_var time')
    istatus = nf90_put_var(ncid, timebndsvarid, time_bnds)
    CALL handle_err(istatus,'nf90_put_var time_bnds')

  ENDIF ! dseconds /= 0

!... loop over the variables in the mapping file
  DO i = 1, nlines
    istatus = nf90_inq_varid(ncid, TRIM(param_icon(i)), varid)
    IF (istatus == NF90_NOERR) THEN
      istatus = nf90_redef(ncid)
      CALL handle_err(istatus,'nf90_redef')
      istatus = nf90_rename_var(ncid, varid, TRIM(param_clm(i)))
      CALL handle_err(istatus,'nf90_rename_var '//TRIM(param_icon(i))//' to '//TRIM(param_clm(i)))

!...  correct the standard_name
      IF ( TRIM(standard_name(i)) == "-") THEN
        istatus = nf90_del_att(ncid, varid, "standard_name")
        CALL handle_err(istatus,'nf90_del_att standard_name')
      ELSE
        istatus = nf90_put_att(ncid, varid, "standard_name", TRIM(standard_name(i))) 
        CALL handle_err(istatus,'nf90_put_att standard_name '//TRIM(standard_name(i)))
     ENDIF

!...  correct cell_methods
    SELECT CASE (TRIM(operation))

      CASE ("mean")
        ! for operation="mean" set cell_methods for the time interval and change the variable name
        IF (TRIM(param_icon(i)) == 'qhfl_s') THEN
          ALLOCATE (array2d(ncells,1))
         istatus = nf90_enddef(ncid)
         CALL handle_err(istatus,'nf90_enddef')
         istatus = nf90_get_var(ncid, varid, array2d)
          CALL handle_err(istatus,'nf90_get_var'//TRIM(param_clm(i)))
          istatus = nf90_get_att(ncid, varid, "_FillValue", undef)
          CALL handle_err(istatus,'nf90_get_att _FillValue')
          WHERE (array2d /= undef) array2d = array2d * dseconds
          istatus = nf90_put_var(ncid, varid, array2d)
          CALL handle_err(istatus,'nf90_put_var'//TRIM(param_clm(i)))
          istatus = nf90_redef(ncid)
          CALL handle_err(istatus,'nf90_redef')
          DEALLOCATE (array2d)
          istatus = nf90_put_att(ncid, varid, "cell_methods", "time: sum") 
          CALL handle_err(istatus,'nf90_put_att cell_methods time'//TRIM(param_clm_a(i)))
          istatus = nf90_rename_var(ncid, varid,TRIM(param_clm_a(i)))          
          CALL handle_err(istatus,'nf90_rename_var '//TRIM(param_clm(i))//" to "//TRIM(param_clm_a(i)))         
        ELSE
          IF (TRIM(param_clm_a(i)) /= '-') THEN
             ! Change 
            istatus = nf90_put_att(ncid, varid, "cell_methods", "time: mean") 
            CALL handle_err(istatus,'nf90_put_att cell_methods time'//TRIM(param_clm_a(i)))
            istatus = nf90_rename_var(ncid, varid,TRIM(param_clm_a(i)))
            CALL handle_err(istatus,'nf90_rename_var '//TRIM(param_clm(i))//" to "//TRIM(param_clm_a(i)))         
          ELSE
            ! Add an "A" as prefix to the variable name
            istatus = nf90_put_att(ncid, varid, "cell_methods", "time: mean") 
            CALL handle_err(istatus,'nf90_put_att cell_methods time A'//TRIM(param_clm(i)))
            istatus = nf90_rename_var(ncid, varid,"A"//TRIM(param_clm(i)))
            CALL handle_err(istatus,'nf90_rename_var '//TRIM(param_clm(i))//" to A"//TRIM(param_clm(i)))
          ENDIF
        ENDIF
        IF ( TRIM(standard_name_a(i)) /= "-") THEN
          istatus = nf90_put_att(ncid, varid, "standard_name", TRIM(standard_name_a(i))) 
          CALL handle_err(istatus,'nf90_put_att standard_name '//TRIM(standard_name_a(i)))
        ENDIF
        IF ( TRIM(units_a(i)) /= "-") THEN
          istatus = nf90_put_att(ncid, varid, "units", TRIM(units_a(i))) 
          CALL handle_err(istatus,'nf90_put_att units '//TRIM(units_a(i)))
        ENDIF

      CASE ("max")
        ! for operation="max" set cell_methods for the time interval and change the variable name
        CALL handle_err(istatus,'nf90_redef')
        IF ((index(TRIM(param_clm(i)), "_2M") == 0) .AND. (index(TRIM(param_clm(i)), "_10M") == 0)) THEN
          new_name = TRIM(param_clm(i))//"MAX"
        ELSE
          IF (index(TRIM(param_clm(i)), "_2M") /= 0) THEN
            index_suffix = index(TRIM(param_clm(i)), "_2M") - 1
            new_name = param_clm(i)(1:index_suffix)//"MAX_2M"
          ELSEIF (index(TRIM(param_clm(i)), "_10M") /= 0) THEN
            index_suffix = index(TRIM(param_clm(i)), "_10M") - 1
            new_name = param_clm(i)(1:index_suffix)//"MAX_10M"
          ENDIF
        ENDIF
        istatus = nf90_rename_var(ncid, varid, TRIM(new_name))
        CALL handle_err(istatus,'nf90_rename_var '//TRIM(param_icon(i))//' to '//TRIM(new_name))
        istatus = nf90_put_att(ncid, varid, "cell_methods", "time: maximum")
        CALL handle_err(istatus,'nf90_put_att cell_methods time maximum')
        istatus = nf90_get_att(ncid, varid, "long_name", long_name)
        long_name = "maximum of "//TRIM(long_name)
        istatus = nf90_put_att(ncid, varid, "long_name", long_name)

      CASE ("min")
        ! for operation="min" set cell_methods for the time interval and change the variable name
        CALL handle_err(istatus,'nf90_redef')
        IF ((index(TRIM(param_clm(i)), "_2M") == 0) .AND. (index(TRIM(param_clm(i)), "_10M") == 0)) THEN
          new_name = TRIM(param_clm(i))//"MIN"
        ELSE
          IF (index(TRIM(param_clm(i)), "_2M") /= 0) THEN
            index_suffix = index(TRIM(param_clm(i)), "_2M") - 1
            new_name = param_clm(i)(1:index_suffix)//"MIN_2M"
          ELSEIF (index(TRIM(param_clm(i)), "_10M") /= 0) THEN
            index_suffix = index(TRIM(param_clm(i)), "_10M") - 1
            new_name = param_clm(i)(1:index_suffix)//"MIN_10M"
          ENDIF
        ENDIF
        istatus = nf90_rename_var(ncid, varid, TRIM(new_name))
        CALL handle_err(istatus,'nf90_rename_var '//TRIM(param_icon(i))//' to '//TRIM(new_name))
        istatus = nf90_put_att(ncid, varid, "cell_methods", "time: minimum")
        CALL handle_err(istatus,'nf90_put_att cell_methods time minimum')
        istatus = nf90_get_att(ncid, varid, "long_name", long_name)
        long_name = "minimum of "//TRIM(long_name)
        istatus = nf90_put_att(ncid, varid, "long_name", long_name)

      CASE default
        IF (TRIM(cell_method(i)) == "mean") THEN
          ! for variables with cell_method == "mean" from the mapping file the mean is since model start
          istatus = nf90_put_att(ncid, varid, "mean_over_time", "since model start")
          CALL handle_err(istatus,'nf90_put_att mean_over_time '//TRIM(param_clm(i)))       
        ELSE
          ! for all other variables take the cell_method from the mapping file
          istatus = nf90_put_att(ncid, varid, "cell_methods", "time: "//TRIM(cell_method(i))) 
          CALL handle_err(istatus,'nf90_put_att cell_methods time '//TRIM(param_clm(i)))
        ENDIF

      END SELECT



      istatus = nf90_enddef(ncid)
      CALL handle_err(istatus,'nf90_enddef')
   !...  rename height dimension and variable
      IF (TRIM(height(i)) == '2' .OR. TRIM(height(i)) == '10') THEN
        istatus = nf90_redef(ncid)
        CALL handle_err(istatus,'nf90_redef')
        istatus = nf90_put_att(ncid, varid, "coordinates", "clon clat height_"//TRIM(height(i))//"m")
        CALL handle_err(istatus,"nf90_put_att coordinates clon clat height_"//TRIM(height(i))//"m")
        istatus = nf90_enddef(ncid)
        CALL handle_err(istatus,'nf90_enddef')
        istatus = nf90_inquire_variable(ncid, varid, ndims=numdims, dimids=dimids)
        CALL handle_err(istatus,'nf90_inquire_variable '//TRIM(param_clm(i)))
        DO idim = 1, numdims
         istatus = nf90_inquire_dimension(ncid, dimids(idim), dimname)
         CALL handle_err(istatus,'nf90_inquire_dimension '//TRIM(dimname))
         IF (TRIM(dimname) == 'time' .OR. TRIM(dimname) == 'ncells') CYCLE
         IF (TRIM(dimname) == 'height_2m' .OR. TRIM(dimname) == 'height_10m') CYCLE
         istatus = nf90_inq_varid(ncid, TRIM(dimname), varid2)
         CALL handle_err(istatus,'nf90_inq_varid '//TRIM(dimname))
         istatus = nf90_redef(ncid)
         CALL handle_err(istatus,'nf90_redef')
         istatus = nf90_rename_dim(ncid, dimids(idim), "height_"//TRIM(height(i))//"m")
         CALL handle_err(istatus,'nf90_rename_dim '//"height_"//TRIM(height(i))//"m")
         istatus = nf90_rename_var(ncid, varid2, "height_"//TRIM(height(i))//"m")
         CALL handle_err(istatus,'nf90_rename_var '//"height_"//TRIM(height(i))//"m")
      !... add attributes
         istatus = nf90_put_att(ncid, varid2, "standard_name", "height")
         CALL handle_err(istatus,'nf90_put_att height standard_name')
         istatus = nf90_put_att(ncid, varid2, "long_name", "height above the surface")
         CALL handle_err(istatus,'nf90_put_att height long_name')
         istatus = nf90_put_att(ncid, varid2, "units", "m")
         CALL handle_err(istatus,'nf90_put_att height units')
         istatus = nf90_put_att(ncid, varid2, "axis", "Z")
         CALL handle_err(istatus,'nf90_put_att height axis')
         istatus = nf90_put_att(ncid, varid2, "positive", "up")
         CALL handle_err(istatus,'nf90_put_att height positive')

         istatus = nf90_enddef(ncid)
         CALL handle_err(istatus,'nf90_enddef')
         READ(height(i),*) rheight
         istatus = nf90_put_var (ncid, varid2, rheight)
         CALL handle_err(istatus,'nf90_put_var '//"height_"//TRIM(height(i))//"m")
         EXIT
        ENDDO
      ENDIF
    ENDIF

  ENDDO
  
  istatus = nf90_close (ncid)
  CALL handle_err(istatus,'nf90_close')

! release the mapping file
  CALL f%destroy()

END PROGRAM correct_cf
