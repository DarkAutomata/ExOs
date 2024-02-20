@echo off

:: First parameter is the win32-compatible WSL directory.
pushd %1
shift

:: Determine the full command line 
set fullCmd=

:ArgLoop
    if "%1"=="" goto:ArgLoopDone
    
    set fullCmd=%fullCmd%%1 
    shift
    
    goto:ArgLoop

:ArgLoopDone

:: Configure VS build tools.

CALL "C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\VC\Auxiliary\Build\vcvars64.bat" > nul 2>&1

:: Execute entire command line.
echo %fullCmd%
%fullCmd%

popd

