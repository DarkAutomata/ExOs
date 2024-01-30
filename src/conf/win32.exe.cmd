@echo off
:: Configure VS build tools.

CALL "C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\VC\Auxiliary\Build\vcvars64.bat"

:: Execute entire command line.
echo %*
%*

