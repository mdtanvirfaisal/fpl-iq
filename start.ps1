Write-Host "========================================================" -ForegroundColor Green
Write-Host "            Starting FPL IQ Backend Server              " -ForegroundColor Cyan
Write-Host "========================================================" -ForegroundColor Green

$env:PYTHONPATH = "backend"
& ".\backend\.venv\Scripts\python.exe" -m uvicorn app.main:app --app-dir backend --reload --port 8000
