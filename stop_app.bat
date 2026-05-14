@echo off
setlocal enabledelayedexpansion

set "APP_PORT=3000"
set "ENV_FILE=%~dp0server\.env"

if exist "%ENV_FILE%" (
  for /f "usebackq tokens=1,* delims==" %%A in ("%ENV_FILE%") do (
    if /I "%%A"=="PORT" set "APP_PORT=%%B"
  )
)

echo Stopping app on port %APP_PORT% ...

set "FOUND=0"
for /f "tokens=5" %%P in ('netstat -ano ^| findstr /R /C:":%APP_PORT% .*LISTENING"') do (
  set "FOUND=1"
  echo Killing PID %%P
  taskkill /PID %%P /F >nul 2>&1
)

if "%FOUND%"=="0" (
  echo No LISTENING process found on port %APP_PORT%.
) else (
  echo Stop completed.
)

endlocal
