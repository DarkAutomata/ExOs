# 
# Include cfg.pre.inc to pull in variable and other definitions.
#
PRJ_ROOT=../../..
CUR_PATH=hal/x86/ldr

include $(PRJ_ROOT)/conf/bld.sys.init.mk

BLD_TARGETS=\
	$(BLD_OUT)/boot_rs232.bin\

BLD_PACKAGES=\

include $(CONF_ROOT)/bld.env.x86.preboot.mk


$(BLD_OUT)/boot_rs232.bin: $(BLD_OUT)/boot_rs232.o
	echo CREATE BOOT IMAGE.

$(BLD_OUT)/%.o: %.asm
	$(BLD_TOOL_NASM) -f bin -o $@ -l $@.lst $<



