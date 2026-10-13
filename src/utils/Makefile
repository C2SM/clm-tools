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
PARENTDIR    = $(STDROOT)/..
SRCDIR       = $(STDROOT)/src
OBJDIR       = $(STDROOT)/obj
EXEDIR       = $(STDROOT)/bin
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

all: ccaf2icaf_exe correct_cf_exe

ccaf2icaf_exe: $(OBJDIR) $(UTILS_OBJ) $(CCAF2ICAF_OBJ)
	echo creating executable ccaf2icaf
	( $(FC) $(LDFLAGS) -o $(CCAF2ICAF_PROGRAM) $(UTILS_OBJ) $(CCAF2ICAF_OBJ) $(LIBS) )
	echo "executable ccaf2icaf created successfully"
                                    
correct_cf_exe: $(OBJDIR) $(UTILS_OBJ) $(CORRECT_CF_OBJ)
	echo creating executable correct_cf
	( $(FC) $(LDFLAGS) -o $(CORRECT_CF_PROGRAM) $(UTILS_OBJ) $(CORRECT_CF_OBJ) $(LIBS) )
	echo "executable correct_cf created successfully"
#
clean:
	echo cleaning up
	rm -f bin/*
	rm -f $(OBJDIR)/*.o
	rm -f $(OBJDIR)/*.mod

####################################################
#
#     Dependencies of the Modules
#
####################################################
#

include ObjDependencies
