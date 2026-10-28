@echo off
rem Print the model's accuracy from the saved evaluation artefacts in ml\output.
rem Uses ml\.venv when it exists, otherwise any Python 3.11 on the machine.
setlocal
cd /d "%~dp0.."
if exist "ml\.venv\Scripts\python.exe" (
    "ml\.venv\Scripts\python.exe" -m ml.show_accuracy %*
) else (
    py -3.11 -m ml.show_accuracy %*
)
exit /b %ERRORLEVEL%
