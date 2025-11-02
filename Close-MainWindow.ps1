<#
.SYNOPSIS
Close the main window of a specified process and optionally force kill it after a timeout.

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

$LogFile = Join-Path $PSScriptRoot '\Close-MainWindow.log'
Set-Content -Path $LogFile -Value "[$(Get-Date -Format o)] Starting Close-MainWindow for process $ProcessName" -Encoding UTF8
# Define once (put in a module or at top of script)

function Write-Log {
    [CmdletBinding()]
    param(
        [Parameter(ValueFromPipeline=$true, Position=0)]
        [object]$Message,

        [Parameter(Position=1)]
        [ValidateSet('DEBUG','INFO','WARN','ERROR')]
        [string]$Level = 'INFO',

        [Parameter()]
        [string]$FilePath = $LogFile
    )

    begin {
        $buffer = [System.Collections.Generic.List[string]]::new()
    }

    process {
        if ($null -eq $Message) { return }

        # If a complex object arrives, get its formatted text
        $textLines = if ($Message -is [string]) {
            $Message -split "`n"
        } else {
            $Message | Out-String -Stream
        }

        $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
        foreach ($line in $textLines) {
            $buffer.Add("$timestamp [$Level] $line")
        }

        # Optional: flush periodically to avoid high memory usage
        if ($buffer.Count -ge 200) {
            $buffer | Add-Content -Path $FilePath -Encoding UTF8
            $buffer.Clear()
        }
    }

    end {
        if ($buffer.Count -gt 0) {
            $buffer | Add-Content -Path $FilePath -Encoding UTF8
        }
    }
}

# Obtener proceso
$proc = Get-Process -Name "$ProcessName" -ErrorAction SilentlyContinue
if (! $proc) {
    "$ProcessName is not running." | Write-Log -Level INFO
    exit 0
}  # It's not running

if ($proc -is [System.Array]) {
    # Multiple processes found, take the first one
    # If this happens often, consider improving the the rest of the script to handle multiple instances
    $proc = $proc[0]
    "Multiple instances of $ProcessName found. Operating on PID: $($proc.Id)" | Write-Log -Level WARN
}   

# Ask a clean close. Wait and ask again to close parent window
"Closing main window of $ProcessName (PID: $($proc.Id))" | Write-Log -Level INFO
$proc.CloseMainWindow()
Start-Sleep -Seconds 5
"Checking if $ProcessName is still running after CloseMainWindow" | Write-Log -Level INFO
if ($proc = Get-Process -Name "$ProcessName") {
    "Process $ProcessName is still running. Attempting to close main window again." | Write-Log -Level WARN
    $proc.CloseMainWindow()
} else {
    "Process $ProcessName has exited after CloseMainWindow." | Write-Log -Level INFO
    exit 0
}


# Optional: wait and, if still running, force kill
if ( $proc.WaitForExit($WaitMiliSeconds)) {
    exit 0
} else {
    "Process $ProcessName is still running after waiting $WaitMiliSeconds seconds. Forcing termination." | Write-Log -Level WARN
    $proc.Kill()
}

if (! $proc.WaitForExit($WaitMiliSeconds)) {
    Write-Warning "Process $ProcessName did not exit after Kill."
    "Process $ProcessName did not exit after Kill." | Write-Log -Level ERROR
    exit 1
}