ENV.WIN32.WSL.ROOT=//wsl$$/Ubuntu
ENV.WIN32.CL=/bin/bash $(CONF_ROOT)/bld.tool.win32 $(ENV.WIN32.WSL.ROOT) cl.exe 
ENV.WIN32.LINK=/bin/bash $(CONF_ROOT)/bld.tool.win32 $(ENV.WIN32.WSL.ROOT) link.exe 
ENV.PREBOOT.NASM=nasm

