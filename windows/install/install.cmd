@echo off
rem Installs the Splitter virtual cables (asks for administrator rights).
rem Options are passed on to install.ps1, e.g.: install.cmd -Force
rem Exit code: the script's, also when it ran in an elevated window of its own.
rem SPLITTER_NOPAUSE=1 skips the wait for a key (for scripts and terminals).
rem Administrator? fltmc only runs for one. "net session" was used before,
rem but it also fails for an administrator when the Server service is off,
rem and then this asked for rights again and again.
fltmc >nul 2>&1
if errorlevel 1 goto elevate
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0install.ps1" %*
set "SPLITTER_RC=%errorlevel%"
echo.
if not defined SPLITTER_NOPAUSE pause
exit /b %SPLITTER_RC%

:elevate
rem Hand path and options over in variables, so quotes or apostrophes
rem in them can't break the PowerShell command. The elevated copy runs in a
rem window of its own; this one waits for it and returns its exit code. If
rem asking for rights fails (the prompt was cancelled), say so: the window
rem would close with the error unread.
set "SPLITTER_SELF=%~f0"
set "SPLITTER_ARGS=%*"
powershell -NoProfile -Command "$a = $env:SPLITTER_ARGS; try { $p = if ($a) { Start-Process -FilePath $env:SPLITTER_SELF -ArgumentList $a -Verb RunAs -Wait -PassThru } else { Start-Process -FilePath $env:SPLITTER_SELF -Verb RunAs -Wait -PassThru }; exit $p.ExitCode } catch { Write-Host 'Administrator rights are needed, and they were not given.'; exit 1 }"
set "SPLITTER_RC=%errorlevel%"
if %SPLITTER_RC% neq 0 if not defined SPLITTER_NOPAUSE pause
exit /b %SPLITTER_RC%
