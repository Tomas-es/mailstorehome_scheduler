<#
.SYNOPSIS
Waits until the MailStore data folder shows no write activity for a short idle interval.

.DESCRIPTION
Monitors a folder (recursively) for write activity on typical MailStore files.
The script checks the maximum LastWriteTimeUtc of matching files every 5 seconds 
and exits 0 when that timestamp hasn't changed for the configured idle period.
Returns 1 on timeout or error.

.PARAMETER Folder
Path to the MailStore data folder. Default: $env:USERPROFILE\Documents\MailStore Home

.PARAMETER IdleSec
Number of seconds with no file writes required to consider the folder idle. Default: 10

.PARAMETER MaxWaitMin
Maximum number of minutes to wait before timing out. Default: 30
Keeps the script from waiting indefinitely.

.PARAMETER Patterns
Array of glob patterns to include when checking files. Default: *.dat,*.fdb,*.rr,*.key,Index*.dat

.EXAMPLE
PS> .\WaitForMailStoreIdle.ps1 -Folder "$env:USERPROFILE\Documents\MailStore Home" -IdleSec 10 -MaxWaitMin 30
#>

[CmdletBinding()]
param(
    [string]$Folder = "D:\MailStoreAdministrador",
    [int]$IdleSec = 10,
    [int]$MaxWaitMin = 3,
    [string[]]$Patterns = @('*.lock','*.fdb','*.key','Index*.dat')
)

$referenceTime = Get-Date
# Give time to the first change to happen 
Write-Verbose "Give time to the first change to happen "
Start-Sleep -Seconds $IdleSec

$lastModifiedFile = Get-ChildItem -Path D:\MailStoreAdministrador | Sort-Object -Property LastWriteTime | Select-Object -Last 1
$lastWriteTime =  $lastModifiedFile.LastWriteTime
Write-Verbose $lastModifiedFile

while ( $lastWriteTime -gt $referenceTime){
	Start-Sleep -Seconds 5
    $referenceTime = $lastWriteTime
	$lastModifiedFile = Get-ChildItem -Path D:\MailStoreAdministrador | Sort-Object -Property LastWriteTime | Select-Object -Last 1
	$lastWriteTime =  $lastModifiedFile.LastWriteTime
	Write-Verbose $lastModifiedFile
    if ( (Get-Date) -gt ( $lastWriteTime.AddMinutes($MaxWaitMin) ) ){
        Write-Warning "Timeout waiting for folder to be idle"
        exit 1
    }
}

$lastModifiedFile = Get-ChildItem -Path D:\MailStoreAdministrador | Sort-Object -Property LastWriteTime |
 Select-Object -Last 6 | Out-File -FilePath .\LastModified.txt
Write-Verbose "Folder idle for more tan $IdleSec seconds"

exit 0
