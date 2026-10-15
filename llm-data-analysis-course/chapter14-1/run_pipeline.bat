
@echo off
setlocal

cd /d "%~dp0"

set "PYTHON=%~dp0..\..\.venv\Scripts\python.exe"

if not exist "%PYTHON%" (
    echo [FAIL] Python executable not found
    exit /b 1
)

echo === Tourism Pipeline Start ===

"%PYTHON%" "%~dp0run_pipeline.py"

set "EXIT_CODE=%ERRORLEVEL%"

if not "%EXIT_CODE%"=="0" (
    echo [FAIL] Pipeline failed
    exit /b %EXIT_CODE%
)

echo === Tourism Pipeline Complete ===

exit /b 0
