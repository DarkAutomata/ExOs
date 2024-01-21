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
.PHONY: bld_stage_clean $(addprefix bld_stage_clean_,$(BLD_TARGETS))
bld_stage_clean: $(addprefix bld_stage_clean_,$(BLD_TARGETS))

.PHONY: bld_stage_init $(addprefix bld_stage_init_,$(BLD_TARGETS))
bld_stage_init: $(addprefix bld_stage_init_,$(BLD_TARGETS))

.PHONY: bld_stage_build $(addprefix bld_stage_build_,$(BLD_TARGETS))
bld_stage_build: $(addprefix bld_stage_build_,$(BLD_TARGETS))

.PHONY: bld_stage_package $(addprefix bld_stage_build_,$(BLD_TARGETS))
bld_stage_package: $(addprefix bld_stage_build_,$(BLD_TARGERS))

# 
# Generate the build stages for each directory.
# 
define BLD_TEMPLATE
bld_stage_clean_$(1):
	$(MAKE) -C $(1) bld_stage_clean

bld_stage_init_$(1):
	$(MAKE) -C $(1) bld_stage_init

bld_stage_build_$(1):
	$(MAKE) -C $(1) bld_stage_build

bld_stage_package_$(1):
	$(MAKE) -C $(1) bld_stage_package

endef

$(foreach targetDir,$(BLD_TARGETS),$(eval $(call BLD_TEMPLATE,$(targetDir))))

