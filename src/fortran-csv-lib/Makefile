####################################################
#
#    Makefile for the Fortran 90 program
#
####################################################
#
#
####################################################
#
#    Declaration of Variables
#
####################################################
#
.SILENT:
#
STDROOT      = $(PWD)
SRCDIR       = $(STDROOT)/src
OBJDIR       = $(STDROOT)/obj
WORKDIR      = $(STDROOT)/work
LIBDIR       = $(STDROOT)/lib
INCDIR       = $(STDROOT)/include
#
#
#########
#  include file containing system special configurations
#########
#
include Fopts
#
####################################################
#
#     Declaration of the Object Files
#
####################################################
#
include ObjFiles
#
####################################################
#
#     Actions that can be performed
#
####################################################
#
#
.PHONY: lib clean

lib:  $(OBJECTS)
	@ echo " creating library libcsv "
	@ rm -f ${LIBDIR}/libcsv.a
	@ ar -qv ${LIBDIR}/libcsv.a $(OBJECTS)
	@ cp $(OBJDIR)/*.mod $(INCDIR)
	echo "library libcsv compiled successfully"
#
clean:
	echo cleaning up
	rm -f $(LIBDIR)/libcsv.a
	rm -f $(OBJDIR)/*.o
	rm -f $(OBJDIR)/*.mod
	rm -f $(INCDIR)/*.mod

#
####################################################
#
#     Dependencies of the Data Modules
#
####################################################
#

include ObjDependencies

