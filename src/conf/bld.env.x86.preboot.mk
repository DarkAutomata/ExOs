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

include $(CONF_ROOT)/local.env.mk


# 
# x86 preboot (bare) tooling.
# 

BLD_TOOL_NASM=$(ENV.PREBOOT.NASM)

#
# Preserve intermediate targets.
#
.SECONDARY: $(BLD_OBJ_TARGETS)

$(BLD_OUT)/%.o: %.asm
	$(BLD_TOOL_NASM) -f bin -o $@ -l $(@:.o=.lst) $<

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


