@echo off
rem Installs the Splitter virtual cables (asks for administrator rights).
rem Options are passed on to install.ps1, e.g.: install.cmd -Force
rem Administrator? fltmc only runs for one. "net session" was used before,
rem but it also fails for an administrator when the Server service is off,
rem and then this asked for rights again and again.
fltmc >nul 2>&1
if %errorlevel% neq 0 (
    rem Hand path and options over in variables, so quotes or apostrophes
    rem in them can't break the PowerShell command.
    set "SPLITTER_SELF=%~f0"
    set "SPLITTER_ARGS=%*"
    powershell -NoProfile -Command "$a = $env:SPLITTER_ARGS; if ($a) { Start-Process -FilePath $env:SPLITTER_SELF -ArgumentList $a -Verb RunAs } else { Start-Process -FilePath $env:SPLITTER_SELF -Verb RunAs }"
    rem If asking for rights failed (the prompt was cancelled), say so and
    rem keep the window open: it would close with the error unread.
    if errorlevel 1 (
        echo.
        echo Administrator rights are needed, and they were not given.
        if not defined SPLITTER_NOPAUSE pause
        exit /b 1
    )
    exit /b 0
)
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0install.ps1" %*
set "SPLITTER_RC=%errorlevel%"
echo.
rem SPLITTER_NOPAUSE=1 skips the wait for a key (for scripts and terminals).
if not defined SPLITTER_NOPAUSE pause
exit /b %SPLITTER_RC%
