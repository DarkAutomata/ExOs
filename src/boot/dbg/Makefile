# 
# Include cfg.pre.inc to pull in variable and other definitions.
#
PRJ_ROOT=../..
CUR_PATH=boot/dbg

include $(PRJ_ROOT)/conf/bld.sys.init.mk

BLD_OBJ_TARGETS=\
	$(BLD_OUT)/main.obj

BLD_TARGETS=\
	$(BLD_OUT)/exosdb.exe

BLD_PACKAGES=\

all: exe
exe: $(BLD_OUT)/exosdb.exe

$(BLD_OUT)/exosdb.exe: $(BLD_OBJ_TARGETS)
	$(BLD_TOOL_LINK) /NOLOGO $(BLD_OBJ_TARGETS) "/OUT:$@" "/PDB:$(@:.exe=.pdb)"

# 
# Execute the data configured above according to standard build system rules.
#
include $(CONF_ROOT)/bld.env.win32.mk

