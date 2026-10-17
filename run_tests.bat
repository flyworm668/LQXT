@echo off
setlocal
set "GODOT=D:\Claude_test\godot_4.7.2\Godot_v4.7.2-stable_win64.exe"
if not exist "%GODOT%" (
  echo Godot not found at:
  echo   %GODOT%
  pause
  exit /b 1
)
"%GODOT%" --headless --path "%~dp0" -- --test
pause
