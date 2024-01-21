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

# 
# x86 preboot (bare) tooling.
# 

BLD_TOOL_NASM=nasm

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

