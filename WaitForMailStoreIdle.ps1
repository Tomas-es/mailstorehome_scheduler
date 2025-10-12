<#
.SYNOPSIS
Waits until the MailStore data folder shows no write activity for a short idle interval.

.DESCRIPTION
Monitors a folder (recursively) for write activity on typical MailStore files. The script checks the maximum LastWriteTimeUtc of matching files every 5 seconds and exits 0 when that timestamp hasn't changed for the configured idle period. Returns 1 on timeout or error.

.PARAMETER Folder
Path to the MailStore data folder. Default: $env:USERPROFILE\Documents\MailStore Home

.PARAMETER IdleSec
Number of seconds with no file writes required to consider the folder idle. Default: 10

.PARAMETER MaxWaitMin
Maximum number of minutes to wait before timing out. Default: 30

.PARAMETER Patterns
Array of glob patterns to include when checking files. Default: *.dat,*.fdb,*.rr,*.key,Index*.dat

.EXAMPLE
PS> .\WaitForMailStoreIdle.ps1 -Folder "$env:USERPROFILE\Documents\MailStore Home" -IdleSec 10 -MaxWaitMin 30
#>

[CmdletBinding()]
param(
    [string]$Folder = "$env:USERPROFILE\Documents\MailStore Home",
    [int]$IdleSec = 10,
    [int]$MaxWaitMin = 30,
    [string[]]$Patterns = @('*.dat','*.fdb','*.rr','*.key','Index*.dat')
)

# Validate folder
if (-not (Test-Path -LiteralPath $Folder)){
    Write-Error "Folder not found: $Folder"
    exit 1
}

function Get-LatestWriteTicks {
    param([string]$path, [string[]]$patterns)
    try{
        $items = Get-ChildItem -Path $path -Recurse -ErrorAction SilentlyContinue -File | Where-Object { foreach($p in $patterns){ if ($_.Name -like $p){ return $true } } ; $false }
        if (-not $items){ return $null }
        return ($items | ForEach-Object { $_.LastWriteTimeUtc.Ticks } | Measure-Object -Maximum).Maximum
    } catch {
        return $null
    }
}

$maxWait = (Get-Date).AddMinutes($MaxWaitMin)
$last = Get-LatestWriteTicks -path $Folder -patterns $Patterns
if (-not $last){ Write-Verbose "No files matched patterns in $Folder"; exit 0 }

Write-Verbose "Waiting for folder to be idle: $Folder (idleSec=$IdleSec, maxWaitMin=$MaxWaitMin)"
while((Get-Date) -lt $maxWait){
    Start-Sleep -Seconds 5
    $cur = Get-LatestWriteTicks -path $Folder -patterns $Patterns
    if (-not $cur){ Write-Verbose "No files matched patterns anymore"; exit 0 }
    if ($cur -eq $last){
        # check if it has been idle for IdleSec
        $ageSec = ([DateTime]::UtcNow - [DateTime]::FromFileTimeUtc($cur)).TotalSeconds
        if ($ageSec -ge $IdleSec){
            Write-Verbose "Folder idle for $ageSec seconds"
            exit 0
        }
    } else {
        $last = $cur
    }
}

Write-Error "Timed out waiting for folder to be idle: $Folder"
exit 1
