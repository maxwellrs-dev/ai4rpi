@echo off
REM Wrapper para executar o build via PowerShell, facilitando duplo clique no Windows.
setlocal
set SCRIPT_DIR=%~dp0
powershell -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_DIR%build_tcc.ps1"
set EXITCODE=%ERRORLEVEL%
exit /b %EXITCODE%
