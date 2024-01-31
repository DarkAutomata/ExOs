# 
# The build is split into many phases to satisfy dependencies.
#   
#   bld_stage_clean:
#     - Removes all build data.
#
#   bld_stage_build:
#     - Builds the repository tree.
#

# 
# Define standard processing for the build type using the following known
# variables:
# 
# - BLD_TARGET
#   - The final results in the build directory the rule should produce.
# 
.PHONY: bld_stage_clean $(addprefix bld_stage_clean_,$(BLD_TARGET))
bld_stage_clean: $(addprefix bld_stage_clean_,$(BLD_TARGET))

.PHONY: bld_stage_build $(addprefix bld_stage_build_,$(BLD_TARGET))
bld_stage_build: $(addprefix bld_stage_build_,$(BLD_TARGET))

# 
# Generate the build stages for each directory.
# 
define BLD_TEMPLATE
bld_stage_clean_$(1):
	$(MAKE) -C $(1) bld_stage_clean

bld_stage_build_$(1):
	$(MAKE) -C $(1) bld_stage_build

endef

$(foreach targetDir,$(BLD_TARGET),$(eval $(call BLD_TEMPLATE,$(targetDir))))

