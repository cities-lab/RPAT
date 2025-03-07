ECHO @ECHO off
for /f "skip=2 tokens=2*" %%i in ('REG QUERY HKEY_LOCAL_MACHINE\SOFTWARE\R-core\R /v InstallPath') do (
  set RInstallPath="%%j"
)
@ECHO ON

ECHO %CD%
%RInstallPath%\bin\Rscript run_rpat.R

ECHO *** Press Any Key to Continue ***
PAUSE >NUL
