
SAMOVAR - SAnity check for MOdel VARiables
------------------------------------------------------------------

     SAMOVAR is based on the idea of the SAMOA scripts developed at the 
     Institute for Meteorology and Climate Research (IMK-TRO) 
     at the Karlsruhe Institute of Technology (KIT).
     
     For the runtime environments SPICE and CCLM-SP it was completely rewitten in Fortran.
     The samovar.sh script only runs the `cdo infov` command and converts its output 
     into csv. The samovar program does the check.
     
     Only netCDF format is supported.
     
     
     SAMOVAR is licensed under the GNU GENERAL PUBLIC LICENSE Version 3 
     

Usage:

     samovar.sh <samovar.csv file> <logfile> "<file list>"
     
Output:
 
     A list of variables for each model level that do not pass the test to the logfile.

Compilation:

     The samovar.f90 program needs the netCDF and fortran-csv-lib libraries. 