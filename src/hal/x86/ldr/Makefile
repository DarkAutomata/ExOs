# 
# Include cfg.pre.inc to pull in variable and other definitions.
#
PRJ_ROOT=../../..
CUR_PATH=hal/x86/ldr

include $(PRJ_ROOT)/conf/bld.sys.init.mk

BLD_OBJ_TARGETS=\
	$(BLD_OUT)/boot_rs232.o \
	$(BLD_OUT)/boot_rs232.bin \

BLD_TARGET=\
	$(BLD_OUT)/boot_rs232.bin

$(BLD_OUT)/boot_rs232.bin: $(BLD_OUT)/boot_rs232.o
	cp $< $@

mbr: $(BLD_OUT)/boot_rs232.bin
	dd if=$< of=../vhdimage/ExOs.vhd conv=notrunc

include $(PRJ_ROOT)/conf/bld.env.x86.preboot.mk

