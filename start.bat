@echo off
echo ========================================================
echo               Starting FPL IQ Backend Server             
echo ========================================================
cd /d "%~dp0"
call .\backend\.venv\Scripts\activate.bat
python -m uvicorn app.main:app --app-dir backend --reload --port 8000
pause
