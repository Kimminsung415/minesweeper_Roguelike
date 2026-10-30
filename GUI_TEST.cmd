@echo off
"%~dp0runtime\Godot_v4.5.1-stable_win64_console.exe" --path "%~dp0." --script res://gui_test.gd
set "test_result=%errorlevel%"
if not "%test_result%"=="0" goto finish
"%~dp0runtime\Godot_v4.5.1-stable_win64_console.exe" --path "%~dp0." --script res://shop_gui_test.gd
set "test_result=%errorlevel%"
if not "%test_result%"=="0" goto finish
"%~dp0runtime\Godot_v4.5.1-stable_win64_console.exe" --path "%~dp0." --script res://animation_test.gd
set "test_result=%errorlevel%"
:finish
pause
exit /b %test_result%
