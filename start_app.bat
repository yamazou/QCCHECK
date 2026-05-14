@echo off
setlocal

cd /d "%~dp0server"
if errorlevel 1 (
  echo Failed to move to server directory.
  exit /b 1
)

echo Starting app...
npm start

endlocal
