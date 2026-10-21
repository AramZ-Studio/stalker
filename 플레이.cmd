@echo off
chcp 65001 >nul
cd /d "%~dp0"
if exist ".tools\godot\Godot_v4.6-stable_win64.exe" (
    start "Stalker" ".tools\godot\Godot_v4.6-stable_win64.exe" --path "%~dp0."
) else (
    echo Godot 4.6에서 project.godot를 열고 F5를 누르세요.
    pause
)
