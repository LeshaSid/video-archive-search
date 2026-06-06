@echo off
chcp 65001 >nul
title Video Archive Search Launcher

:: ========================== НАСТРОЙКИ ==========================
set "HF_ENDPOINT=https://hf.at.yandex-team.ru/https/huggingface.co"
set "PYTHONDONTWRITEBYTECODE=1"

set "ROOT_DIR=%~dp0"
set "PORTABLE_DIR=%ROOT_DIR%python_env"

:: Версия Python 3.12 (Embedded)
set "PYTHON_VERSION=3.12.9"
set "PYTHON_ZIP_URL=https://www.python.org/ftp/python/%PYTHON_VERSION%/python-%PYTHON_VERSION%-embed-amd64.zip"
set "GET_PIP_URL=https://bootstrap.pypa.io/get-pip.py"

set "TOML_FILE=%ROOT_DIR%pyproject.toml"
set "REQUIREMENTS_TXT=%PORTABLE_DIR%requirements.txt"

:: ========================== ПРОВЕРКИ ==========================
:: Архитектура
if not "%PROCESSOR_ARCHITECTURE%"=="AMD64" (
    if not "%PROCESSOR_ARCHITEW6432%"=="AMD64" (
        echo [ОШИБКА] Для работы ИИ-моделей необходима 64-битная Windows.
        pause
        exit /b 1
    )
)

:: Наличие pyproject.toml
if not exist "%TOML_FILE%" (
    echo [ОШИБКА] Файл pyproject.toml не найден в папке приложения!
    pause
    exit /b 1
)

:: Быстрый старт, если портативное окружение уже собрано
if exist "%PORTABLE_DIR%\patched.txt" goto LAUNCH_PORTABLE

:: ========================== ВЫБОР PYTHON ==========================
:: Проверяем системный Python версии 3.12+
set "USE_SYSTEM_PYTHON="
python --version >nul 2>&1
if not errorlevel 1 (
    for /f "tokens=2" %%v in ('python --version 2^>^&1') do (
        for /f "tokens=1,2 delims=." %%a in ("%%v") do (
            if %%a EQU 3 if %%b GEQ 12 set "USE_SYSTEM_PYTHON=1"
        )
    )
)

if defined USE_SYSTEM_PYTHON (
    echo [ИНФО] Найден системный Python 3.12+
    call :SETUP_SYSTEM
) else (
    echo [ИНФО] Системный Python отсутствует или устарел, создаю портативное окружение...
    call :SETUP_PORTABLE
)
goto :EOF

:: =================================================================
:: БЛОК 1: Используем системный Python
:: =================================================================
:SETUP_SYSTEM
cd /d "%ROOT_DIR%"
if not exist ".venv" (
    python -m venv .venv
)
call .venv\Scripts\activate.bat
if errorlevel 1 (
    echo [ОШИБКА] Не удалось активировать виртуальное окружение.
    pause
    exit /b 1
)

echo [ИНФО] Установка зависимостей из pyproject.toml...
:: Генерация requirements.txt через временный Python-скрипт
python -c "import tomllib, sys; f=open(r'%TOML_FILE%','rb'); d=tomllib.load(f); deps=d.get('project',{}).get('dependencies',[]); sys.stdout.write('\n'.join(deps))" > "%REQUIREMENTS_TXT%"
if errorlevel 1 (
    echo [ПРЕДУПРЕЖДЕНИЕ] Не удалось распарсить pyproject.toml, пробую установить вручную...
    pip install streamlit qdrant-client sentence-transformers faster-whisper static-ffmpeg
) else (
    pip install --upgrade pip >nul
    pip install -r "%REQUIREMENTS_TXT%"
    del "%REQUIREMENTS_TXT%"
)

goto LAUNCH_SYSTEM

:LAUNCH_SYSTEM
echo [ИНФО] Запуск Video Archive Search...
start "" http://localhost:8501
streamlit run "%ROOT_DIR%main.py" --server.headless true
goto END

:: =================================================================
:: БЛОК 2: Создаём портативный Python (Embedded)
:: =================================================================
:SETUP_PORTABLE
if not exist "%PORTABLE_DIR%" mkdir "%PORTABLE_DIR%"

:: 2.1 Скачиваем Python Embed
echo [1/5] Загрузка Python %PYTHON_VERSION%...
call :DOWNLOAD_FILE "%PYTHON_ZIP_URL%" "%PORTABLE_DIR%\python.zip"
if errorlevel 1 goto DOWNLOAD_FAIL

echo [2/5] Распаковка Python...
powershell -Command "Expand-Archive -Path '%PORTABLE_DIR%\python.zip' -DestinationPath '%PORTABLE_DIR%' -Force"
if errorlevel 1 (
    echo [ОШИБКА] Не удалось распаковать Python.
    pause
    exit /b 1
)
del "%PORTABLE_DIR%\python.zip"

:: 2.2 Настройка ._pth для использования site-packages
set "PTH_FILE=%PORTABLE_DIR%\python%PYTHON_VERSION:~0,2%._pth"
if exist "%PTH_FILE%" (
    echo import sys>> "%PTH_FILE%"
    echo site-packages>> "%PTH_FILE%"
)

:: 2.3 Установка pip
echo [3/5] Установка pip...
call :DOWNLOAD_FILE "%GET_PIP_URL%" "%PORTABLE_DIR%\get-pip.py"
"%PORTABLE_DIR%\python.exe" "%PORTABLE_DIR%\get-pip.py" --no-warn-script-location >nul
del "%PORTABLE_DIR%\get-pip.py"

:: 2.4 Генерация requirements.txt из pyproject.toml
echo [4/5] Подготовка зависимостей...
"%PORTABLE_DIR%\python.exe" -c "import tomllib, sys; f=open(r'%TOML_FILE%','rb'); d=tomllib.load(f); deps=d.get('project',{}).get('dependencies',[]); sys.stdout.write('\n'.join(deps))" > "%REQUIREMENTS_TXT%"
if errorlevel 1 (
    echo [ПРЕДУПРЕЖДЕНИЕ] Не удалось распарсить pyproject.toml, использую стандартный набор...
    (
        echo streamlit
        echo qdrant-client
        echo sentence-transformers
        echo faster-whisper
        echo static-ffmpeg
    ) > "%REQUIREMENTS_TXT%"
)

:: 2.5 Установка зависимостей через pip
echo [5/5] Установка пакетов (может занять несколько минут)...
"%PORTABLE_DIR%\Scripts\pip.exe" install --upgrade pip >nul
"%PORTABLE_DIR%\Scripts\pip.exe" install --no-warn-script-location -r "%REQUIREMENTS_TXT%"
if errorlevel 1 (
    echo [ОШИБКА] Не удалось установить зависимости. Проверьте подключение к интернету.
    pause
    exit /b 1
)

del "%REQUIREMENTS_TXT%"
echo done > "%PORTABLE_DIR%\patched.txt"
goto LAUNCH_PORTABLE

:LAUNCH_PORTABLE
echo [ИНФО] Запуск Video Archive Search...
start "" http://localhost:8501
"%PORTABLE_DIR%\Scripts\streamlit.exe" run "%ROOT_DIR%main.py" --server.headless true
goto END

:: =================================================================
:: ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ
:: =================================================================
:DOWNLOAD_FILE
set "URL=%~1"
set "OUT=%~2"
curl -L --fail --ssl-reqd -o "%OUT%" "%URL%"
if not errorlevel 1 exit /b 0
echo curl не сработал, пробуем powershell...
powershell -Command "& { [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; Invoke-WebRequest -Uri '%URL%' -OutFile '%OUT%' }"
exit /b %errorlevel%

:DOWNLOAD_FAIL
echo [ОШИБКА] Не удалось загрузить файл: %URL%
echo Проверьте доступ к интернету и повторите запуск.
pause
exit /b 1

:END
exit /b 0