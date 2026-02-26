@echo off
setlocal

set "PROJECT_PATH=%~dp0"
if "%PROJECT_PATH:~-1%"=="\" set "PROJECT_PATH=%PROJECT_PATH:~0,-1%"
set "DRIVE=X:"

for /f "tokens=1,* delims=>" %%A in ('subst ^| findstr /I "^%DRIVE%"') do set "CURRENT_MAP=%%B"
if not defined CURRENT_MAP (
  subst %DRIVE% "%PROJECT_PATH%"
) else (
  set "CURRENT_MAP=%CURRENT_MAP:~1%"
  if /I not "%CURRENT_MAP%"=="%PROJECT_PATH%" (
    subst %DRIVE% /d
    subst %DRIVE% "%PROJECT_PATH%"
  )
)

pushd %DRIVE%\
if "%~1"=="" (
  flutter run
) else (
  flutter %*
)
set "EXIT_CODE=%ERRORLEVEL%"
popd

exit /b %EXIT_CODE%
