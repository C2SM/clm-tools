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
#
#########
#  include file containing system special configurations
#########
#
include Fopts
#
#
####################################################
#
#     Declaration of the Object Files
#
####################################################
#
include ObjFiles
#
#
####################################################
#
#     valid actions
#
####################################################
#
#
exe: $(OBJECTS)
	echo "creating cfu executable"
	$(FC) -o $(PROGRAM) $(OBJECTS) $(LIBS)
	echo "executable cfu created successfully"
#
clean:
	echo cleaning up
	rm -f bin/*
	rm -f $(OBJDIR)/*.o
	rm -f $(OBJDIR)/*.mod
#
####################################################
#
#     Dependencies of the Data Modules
#
####################################################
#

include ObjDependencies
