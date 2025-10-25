@echo off
setlocal enabledelayedexpansion

rem === Configuration ===
set MAILSTORE="C:\Program Files (x86)\MailStore\MailStore Home\MailStoreHome.exe"
set LOGDIR=C:\MailStore\Logs
set MAILSCRIPT=C:\MailStore\SendMail.ps1

rem === Verify configured paths exist ===
rem MailStore executable
if not exist %MAILSTORE% (
    echo ERROR: MailStore executable not found: %MAILSTORE%
    echo Please verify the path in this script and that MailStore is installed.
    exit /b 1
)

rem Log directory: create if missing (fail if creation fails)
if not exist "%LOGDIR%" (
    echo Log directory "%LOGDIR%" does not exist. Attempting to create...
    mkdir "%LOGDIR%" 2>nul || (
        echo ERROR: Failed to create log directory "%LOGDIR%"
        exit /b 1
    )
)

rem Mail script
if not exist "%MAILSCRIPT%" (
    echo ERROR: Mail script not found: "%MAILSCRIPT%"
    echo Please ensure SendMail.ps1 exists at the configured path.
    exit /b 1
)

rem Last exited
if exist %MAILSTORE%\*.lock (
    echo  WARNING: Last MailStore exit was not clean. A .lock file exists in %MAILSTORE%.
    echo  This may indicate that MailStore is already running or was not closed properly.
    exit /b 1
)

rem List of profile IDs to run (space-separated)
rem Example: set "PROFILES=1 2 3"
set "PROFILES=1"
set idleSec=20
rem Date format: YYYY-MM-DD_HH-MM-SS
set DATESTAMP=%DATE:~-4%-%DATE:~3,2%-%DATE:~0,2%_%TIME:~0,2%-%TIME:~3,2%-%TIME:~6,2%
rem Replace space with 0 in hour if needed, so there are always two digits and no leading space
set DATESTAMP=%DATESTAMP: =0%


rem === Loop through profiles ===
for %%P in (%PROFILES%) do (
    set "PROFILE=%%~P"
    set "LOGFILE=%LOGDIR%\PROFILE_%%~P_%DATESTAMP%.log"

    (
        echo ======================================================
        echo Running profile: %%~P
        echo Start time: %DATE% %TIME%
        echo ======================================================
    ) >> "!LOGFILE!"

    rem Run MailStore command line
    echo Starting MailStore profile %%~P >> "!LOGFILE!" 2>&1
    start "" %MAILSTORE% /c archive -id="%%~P"
    rem Wait a few seconds to allow MailStore to start properly
    timeout /t 5 /nobreak
    rem Note: ERRORLEVEL is always 0 here because 'start' launches the program and returns immediately.
        (
        echo ERRORLEVEL=%ERRORLEVEL%. It is always 0 because it starts the program,
        echo but not the profile itself if it does not exist.
        echo
        echo For a proper log and result confirmation use the MailStore GUI
        echo and check the profile log there.
    ) >> "!LOGFILE!" 2>&1

    rem Wait until MailStore data directory is idle (no file writes) for %idleSec% seconds, max wait 30 minutes.
    rem Adjust $folder if your MailStore data lives elsewhere.
    rem The following PowerShell command monitors the MailStore data directory for file write activity.
    rem It checks the latest write time of relevant files every 5 seconds and waits until no writes occur for 10 seconds.
    rem If the directory is idle for 10 seconds, it exits with success; otherwise, it times out after 30 minutes.
    rem Call external PowerShell script to wait for MailStore data directory to be idle
    echo '-NoProfile -ExecutionPolicy Bypass -File "%~dp0WaitForMailStoreIdle.ps1" -Folder "%USERPROFILE%\Documents\MailStore Home" -IdleSec %idleSec% -MaxWaitMin 120'
    powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0WaitForMailStoreIdle.ps1" -Folder "%USERPROFILE%\Documents\MailStore Home" -IdleSec %idleSec% -MaxWaitMin 30

    if errorlevel 1 (
      echo WARNING: Wait for MailStore profile %%~P timed out or failed >> "!LOGFILE!"
    ) else (
      echo Profile %%~P appears finished ^(no DB writes for %idleSec% seconds^) >> "!LOGFILE!"
    )

    rem small pause to let MailStore settle
    timeout /t 2 /nobreak >nul

    (
        echo Result: !RESULT!
        echo End time: %DATE% %TIME%
        echo.
    ) >> "!LOGFILE!"

    rem Send email log. Inside the loop to send after each profile.
    rem powershell.exe -ExecutionPolicy Bypass -File "%MAILSCRIPT%" -ProfileName "%%~P" -Result "%RESULT%" -LogFile "!LOGFILE!"
    echo "-ExecutionPolicy Bypass -File "%MAILSCRIPT%" -ProfileName "%%~P" -Result "%RESULT%" -LogFile "!LOGFILE!""
    powershell.exe -ExecutionPolicy Bypass -File .\close-MainWindow.ps1 -ProcessName "MailStoreHome" -WaitSeconds 30
    if errorlevel 1 (
      echo WARNING: Close-MainWindow.ps1 reported an error >> "!LOGFILE!" 2>&1
    ) else (
      echo Close-MainWindow.ps1 completed successfully >> "!LOGFILE!" 2>&1
    )
)

endlocal
