# 
# Include cfg.pre.inc to pull in variable and other definitions.
#
PRJ_ROOT=../

include $(PRJ_ROOT)/cfg/cfg.pre.mk

TARGET_DIR=./boot/
TARGET_TYPE=custom

define BLD_EXEC_PASS_0
echo $(TARGET_DIR) - Pass 0
endef

define BLD_EXEC_PASS_1
echo $(TARGET_DIR) - Pass 1
endef

define BLD_EXEC_PASS_2
echo $(TARGET_DIR) - Pass 2
endef

define BLD_EXEC_PASS_3
echo $(TARGET_DIR) - Pass 3
endef



# 
# Execute the data configured above according to standard build system rules.
#
include $(PRJ_ROOT)/cfg/cfg.post.mk

