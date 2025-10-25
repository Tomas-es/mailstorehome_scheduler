<#
.SYNOPSIS
Close the main window of a specified process and optionally force kill it after a timeout.

.DESCRIPTION
As a graceful way to close MailStore Home before running profiles, this script attempts to close the main window of the specified process.

.PARAMETER ProcessName
Name of the process to close. Default is "MailStoreHome".

.PARAMETER WaitSeconds
Number of seconds to wait for the process to exit after requesting a close. Default is 100.

.EXAMPLE
PS> .\Close-MainWindow.ps1  -ProcessName "MailStoreHome" -WaitSeconds 30

.EXAMPLE
PS> .\Close-MainWindow.ps1  # Uses defaults

.NOTES
Written for MailStore Home log maintenance.
#>


param(
    [string]$ProcessName = "MailStoreHome",
    [int]$WaitSeconds = 100
)

# Obtener proceso
$proc = Get-Process -Name "$ProcessName" -ErrorAction SilentlyContinue
if (! $proc) { exit 0 }  # It's not running

# Ask a clean close. Wait and ask again to close parent window
$proc.CloseMainWindow()
Start-Sleep -Seconds 5
$proc.Refresh()
$proc.CloseMainWindow()

# Optional: wait and, if still running, force kill
if (! $proc.WaitForExit($WaitSeconds)) {
    exit 0
} else {
    $proc.Kill()
}

if (! $proc.WaitForExit($WaitSeconds)) {
    Write-Warning "Process $ProcessName did not exit after Kill."
    exit 1
}