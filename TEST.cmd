@echo off
"%~dp0runtime\Godot_v4.5.1-stable_win64_console.exe" --headless --path "%~dp0." --script res://clear_test.gd
if errorlevel 1 exit /b %errorlevel%
"%~dp0runtime\Godot_v4.5.1-stable_win64_console.exe" --headless --path "%~dp0." --script res://levels_test.gd
pause