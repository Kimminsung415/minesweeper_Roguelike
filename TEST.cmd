@echo off
"%~dp0runtime\Godot_v4.5.1-stable_win64_console.exe" --headless --path "%~dp0." --script res://smoke_test.gd
set "test_result=%errorlevel%"
if not "%test_result%"=="0" goto finish
"%~dp0runtime\Godot_v4.5.1-stable_win64_console.exe" --headless --path "%~dp0." --script res://augment_test.gd
set "test_result=%errorlevel%"
if not "%test_result%"=="0" goto finish
"%~dp0runtime\Godot_v4.5.1-stable_win64_console.exe" --headless --path "%~dp0." --script res://chord_test.gd
set "test_result=%errorlevel%"
if not "%test_result%"=="0" goto finish
"%~dp0runtime\Godot_v4.5.1-stable_win64_console.exe" --headless --path "%~dp0." --script res://shortcut_test.gd
set "test_result=%errorlevel%"
if not "%test_result%"=="0" goto finish
"%~dp0runtime\Godot_v4.5.1-stable_win64_console.exe" --headless --path "%~dp0." --script res://shop_test.gd
set "test_result=%errorlevel%"
:finish
pause
exit /b %test_result%
