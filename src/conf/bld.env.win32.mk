# 
# The build is split into many phases to satisfy dependencies.
#   
#   bld_stage_clean:
#     - Removes all build data.
#
#   bld_stage_build:
#     - Builds the repository tree.
#

include $(CONF_ROOT)/local.env.mk

# 
# Use a win32 toolchain.
# 

BLD_TOOL_CL=$(ENV.WIN32.CL)
BLD_TOOL_LINK=$(ENV.WIN32.LINK)

# 
# Preserve the intermediate targets.
#
.SECONDARY: $(BLD_OBJ_TARGETS)

$(BLD_OUT)/%.obj: %.c
	$(BLD_TOOL_CL) /nologo /Zi /c $< /Fo: "$(BLD_OUT)/" /Fd: "$(BLD_TARGET).bld.pdb"

$(BLD_OUT)/%.exe: $(BLD_OBJ_TARGETS)
	$(BLD_TOOL_LINK) /NOLOGO $(BLD_OBJ_TARGETS) "/OUT:$@" /DEBUG:FULL "/PDB:$(@:.exe=.pdb)"

$(BLD_OUT)/%.dll: $(BLD_OBJ_TARGETS)
	$(BLD_TOOL_LINK) /NOLOGO TODO %(BLD_OBJ_TARGERS) "/OUT:$@" /DEBUG:FULL "/PDB:$(@:.dll=.pdb)"

# 
# Define standard processing for the build type using the following known
# variables:
# 
# - BLD_TARGET
#   - The final results in the build directory the rule should produce.
# 
.PHONY: bld_stage_clean
bld_stage_clean:
	rm -f $(BLD_OUT)/*

$(BLD_OUT):
	mkdir -p $(BLD_OUT)

.PHONY: bld_stage_build
bld_stage_build: $(BLD_OUT) $(BLD_TARGET)

