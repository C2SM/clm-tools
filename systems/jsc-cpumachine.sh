# JSC JURECA-DC; uses csv-fortran instead of fortran-csv-lib, which fails with this gfortran
module --force purge
module load Stages/2024 GCC/12.3.0 OpenMPI/4.1.5 CDO/2.3.0 NCO/5.1.8 netCDF-Fortran/4.6.1 netCDF/4.9.2 Python/3.11.3 CMake/3.26.3
PYTHON=${EBROOTPYTHON}/bin/python
CSV_LIB=csv-fortran
