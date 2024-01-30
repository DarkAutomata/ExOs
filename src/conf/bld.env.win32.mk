# 
# The build is split into many phases to satisfy dependencies.
#   
#   bld_stage_clean:
#     - Removes all build data.
#
#   bld_stage_init:
#     - Builds target folders, provisions libs.
#
#   bld_stage_build:
#     - Builds the repository tree.
#
#   bld_stage_package:
#     - Creates appropriate execution layout.
# 

include $(CONF_ROOT)/local.env.mk

# 
# Use a win32 toolchain.
# 

BLD_TOOL_CL=$(ENV.WIN32.CL)
BLD_TOOL_LINK=$(ENV.WIN32.LINK)

$(BLD_OUT)/%.obj: %.c
	$(BLD_TOOL_CL) /nologo /Zi /c $< /Fo: "$(BLD_OUT)/"

$(BLD_OUT)/%.exe: $(BLD_OBJ_TARGET)
	$(BLD_TOOL_LINK) /NOLOGO $(BLD_OBJ_TARGETS) "/OUT:$@" "/PDB:$(@:.exe=.pdb)"

# 
# Define standard processing for the build type using the following known
# variables:
# 
# - BLD_TARGETS
#   - The final results in the build directory the rule should produce.
# 
.PHONY: bld_stage_clean
bld_stage_clean:
	rm -f $(BLD_OUT)/*

.PHONY: bld_stage_init
bld_stage_init:
	mkdir -p $(BLD_OUT)

.PHONY: bld_stage_build
bld_stage_build: $(BLD_TARGETS)

.PHONY: bld_stage_package
bld_stage_package: $(BLD_PACKAGES)

