@echo off
setlocal
set "GODOT=%~dp0..\Godot_v4.7.1-stable_win64.exe"
set "PROJECT="

for /d %%D in ("%~dp0*") do if exist "%%~fD\project.godot" set "PROJECT=%%~fD"

if not exist "%GODOT%" (
    echo Godot was not found: "%GODOT%"
    echo Keep Godot_v4.7.1-stable_win64.exe beside this game's folder.
    pause
    exit /b 1
)

if not defined PROJECT (
    echo No Godot project was found inside this game's folder.
    pause
    exit /b 1
)

start "" "%GODOT%" --path "%PROJECT%" --max-fps 60 --log-file "%~dp0game_run.log"
if errorlevel 1 (
    echo The game could not be started.
    pause
    exit /b 1
)
