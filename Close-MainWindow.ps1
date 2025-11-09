<#
.SYNOPSIS
Close the main window of a specified process and optionally force kill after a timeout.

.DESCRIPTION
As a graceful way to close MailStore Home before running profiles, this script attempts to close the main window of the specified process.
Then tries again after a short wait if the process is still running. Because MailStore Home uses a main and a child window.
If the process does not exit within the specified wait time, it forcefully terminates the process.

.PARAMETER ProcessName
Name of the process to close. Default is "MailStoreHome".

.PARAMETER WaitMiliSeconds
Number of miliseconds to wait for the process to exit after requesting a close. Default is 3000.

.EXAMPLE
PS> .\Close-MainWindow.ps1  -ProcessName "MailStoreHome" -WaitMiliSeconds 3000

.EXAMPLE
PS> .\Close-MainWindow.ps1  # Uses defaults

.NOTES
Written for MailStore Home log maintenance.
#>


param(
    [string]$ProcessName = "MailStoreHome",
    [int]$WaitMiliSeconds = 3000
)

# Check for Write-Log module file to import
if ( Test-Path -Path $PSScriptRoot\Write-Log.psm1 ) {
    Import-Module $PSScriptRoot\Write-Log.psm1 -NoClobber
} else {
    Set-Content -Path $PSScriptRoot\Wait-MailStoreIdle.txt -Value "Write-Log.psm1 module not found in $PSScriptRoot. Logging will be limited."
}

# Check for existing log file and clear it
$LogFile = Join-Path $PSScriptRoot '\Close-MainWindow.log'
if ( Test-Path $LogFile) {
    Set-Content -Path $LogFile -Encoding UTF8 -Value "Log cleared on $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
}

function Write-CloseWindowLog {
    param (
        [Parameter(ValueFromPipeline=$true, Position=0)]
        [object]$Message,

        [Parameter(Position=1)]
        [ValidateSet('DEBUG','INFO','WARN','ERROR')]
        [string]$Level = 'INFO',

        [Parameter()]
        [string]$FilePath = $LogFile
    )
    Write-Log -Message $Message -Level $Level -FilePath $FilePath    
}
Write-CloseWindowLog "Starting Close-MainWindow aaaaaa for process $ProcessName" -Level 'INFO'
"Test pipe string" | Write-CloseWindowLog -Level 'DEBUG'


# Obtener proceso
$proc = Get-Process -Name "$ProcessName" -ErrorAction SilentlyContinue
if (! $proc) {
    "$ProcessName is not running." | Write-CloseWindowLog -Level INFO
    exit 0
}  # It's not running

if ($proc -is [System.Array]) {
    # Multiple processes found, take the first one
    # If this happens often, consider improving the the rest of the script to handle multiple instances
    $proc = $proc[0]
    "Multiple instances of $ProcessName found. Operating on PID: $($proc.Id)" | Write-CloseWindowLog -Level WARN
}   

# Ask a clean close. Wait and ask again to close parent window
"Closing main window of $ProcessName (PID: $($proc.Id))" | Write-CloseWindowLog -Level INFO
$proc.CloseMainWindow()
Start-Sleep -Seconds 5
"Checking if $ProcessName is still running after CloseMainWindow" | Write-CloseWindowLog -Level INFO
if ($proc = Get-Process -Name "$ProcessName") {
    "Process $ProcessName is still running. Attempting to close main window again." | Write-CloseWindowLog -Level WARN
    $proc.CloseMainWindow()
} else {
    "Process $ProcessName has exited after CloseMainWindow." | Write-CloseWindowLog -Level INFO
    exit 0
}


# Optional: wait and, if still running, force kill
if ( $proc.WaitForExit($WaitMiliSeconds)) {
    exit 0
} else {
    "Process $ProcessName is still running after waiting $WaitMiliSeconds seconds. Forcing termination." | Write-CloseWindowLog -Level WARN
    $proc.Kill()
}

if (! $proc.WaitForExit($WaitMiliSeconds)) {
    Write-Warning "Process $ProcessName did not exit after Kill."
    "Process $ProcessName did not exit after Kill." | Write-CloseWindowLog -Level ERROR
    exit 1
}