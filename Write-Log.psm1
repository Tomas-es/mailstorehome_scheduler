<#
Usage examples
- Piping strings:
'Start task','Step 1 done','Step 2 done' | Write-Log -Level INFO

- Piping command output (objects converted to text):
Get-Process | Write-Log -Level DEBUG

- Use with Select-Object to format before logging:
Get-Service | Select-Object Name,Status | Format-Table -AutoSize | Out-String -Stream | Write-Log -Level INFO

- Direct call with parameter:
Write-Log 'An important event' -Level WARN



Quick notes and best practices
- The function accepts objects, converts them to text, and adds a timestamp and level.
- Buffering reduces disk writes; adjust the threshold (200) according to load.
- If you need to log errors/verbose automatically, redirect streams:
& { Start-Transcript -Path $log; .\script.ps1; Stop-Transcript } 2>&1 | Write-Log
- (converts the combined output to the function).
- For use in shared modules/scripts, export the function or put it in a module.

#>
function Write-Log {
    [CmdletBinding()]
    param(
        [Parameter(ValueFromPipeline=$true, Position=0)]
        [object]$Message,

        [Parameter(Position=1)]
        [ValidateSet('DEBUG','INFO','WARN','ERROR')]
        [string]$Level = 'INFO',

        [Parameter()]
        [string]$FilePath = (Join-Path $PSScriptRoot 'script.log')
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