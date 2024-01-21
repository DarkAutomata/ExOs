# 
# Setup the build environment.
# 
# - Requires:
#   - PRJ_ROOT - The root location of the project.
#   - CUR_PATH - The path of the current directory.
# 
BLD_ARCH=x86

# 
# Define various build system definitions for use while building.
#
BLD_ROOT=$(PRJ_ROOT)/../out/$(BLD_ARCH)
BLD_OUT=$(BLD_ROOT)/$(CUR_PATH)
CONF_ROOT=$(PRJ_ROOT)/conf

# 
# Bring in architecture specific definitions.
#
include $(CONF_ROOT)/arch.$(BLD_ARCH).mk

# 
# Define useful helpers.
#
define bld_tool_asm

endef

# 
# Invoke the appropriate build stages.
#
.PHONY: all
all: package

.PHONY: clean
clean: bld_stage_clean

.PHONY: build
build: bld_stage_init bld_stage_build

.PHONY: package
package: build bld_stage_package

