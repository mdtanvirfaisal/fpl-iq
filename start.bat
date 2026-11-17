@echo off
echo ========================================================
echo               Starting FPL IQ Backend Server             
echo ========================================================
cd /d "%~dp0"
call .\backend\.venv\Scripts\activate.bat
set PYTHONPATH=backend
python -m uvicorn app.main:app --app-dir backend --reload --host 0.0.0.0 --port 8000
pause
