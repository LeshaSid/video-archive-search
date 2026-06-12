::[Bat To Exe Converter]
::
::YAwzoRdxOk+EWAjk
::fBw5plQjdCuDJGmW+0g1Kw9HDDSbKGO1CIkK4ez+4KeGsE4VXfQ6NZze26aNKNwF40HhetssxHlSkd0JQQhdfwCoZkI5qGdMim2GOMnSugzuKg==
::YAwzuBVtJxjWCl3EqQJgSA==
::ZR4luwNxJguZRRnk
::Yhs/ulQjdF+5
::cxAkpRVqdFKZSjk=
::cBs/ulQjdF+5
::ZR41oxFsdFKZSDk=
::eBoioBt6dFKZSDk=
::cRo6pxp7LAbNWATEpCI=
::egkzugNsPRvcWATEpCI=
::dAsiuh18IRvcCxnZtBJQ
::cRYluBh/LU+EWAnk
::YxY4rhs+aU+JeA==
::cxY6rQJ7JhzQF1fEqQJQ
::ZQ05rAF9IBncCkqN+0xwdVs0
::ZQ05rAF9IAHYFVzEqQJQ
::eg0/rx1wNQPfEVWB+kM9LVsJDGQ=
::fBEirQZwNQPfEVWB+kM9LVsJDGQ=
::cRolqwZ3JBvQF1fEqQJQ
::dhA7uBVwLU+EWDk=
::YQ03rBFzNR3SWATElA==
::dhAmsQZ3MwfNWATElA==
::ZQ0/vhVqMQ3MEVWAtB9wSA==
::Zg8zqx1/OA3MEVWAtB9wSA==
::dhA7pRFwIByZRRnk
::Zh4grVQjdCuDJGmW+0g1Kw9HDDSbKGO1CIkK4ez+4KeGsE4VXfQ6NZze26aNKNwF40HhetssxHlSkd0JQQhdfwCoZkI5qGdMinaQOYmZqwqB
::YB416Ek+ZG8=
::
::
::978f952a14a936cc963da21a135fa983
@echo off
title Video Archive Search Launcher

REM Если батник запущен внутри Exe-конвертера, %~dp0 укажет на Temp. 
REM Проверяем, откуда реально запущен процесс:
if defined MYFILESDIR (
    set "ROOT_DIR=%CD%\"
) else (
    set "ROOT_DIR=%~dp0"
)

cd /d "%ROOT_DIR%"

echo [INFO] Working directory is: %ROOT_DIR%

echo [INFO] Checking for UV (Modern Python Package Manager)...
where uv >nul 2>&1
if %errorlevel% neq 0 (
    echo [INFO] UV not found. Downloading standalone UV binary...
    powershell -ExecutionPolicy Bypass -Command "irm https://astral.sh/uv/install.ps1 | iex"
    set "PATH=%USERPROFILE%\.local\bin;%PATH%"
)

echo [INFO] Checking and syncing environment dependencies...
REM Теперь .venv создастся строго в папке с вашим проектом, и uv sync увидит его при втором запуске
uv sync

echo [INFO] Starting Video Archive Search...
start http://127.0.0.1:8501
uv run streamlit run main.py --server.enableCORS false --server.enableXsrfProtection false --server.headless true --server.address 127.0.0.1 --server.fileWatcherType none
pause