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
# Define standard processing for the build type using the following known
# variables:
# 
# - BLD_TARGETS
#   - The final results in the build directory the rule should produce.
# 
.PHONY: bld_stage_clean
bld_stage_clean:

.PHONY: bld_stage_init
bld_stage_init:

.PHONY: bld_stage_build
bld_stage_build: 

.PHONY: bld_stage_package
bld_stage_package:

