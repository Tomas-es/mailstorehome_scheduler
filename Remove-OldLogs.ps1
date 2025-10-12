<#
.SYNOPSIS
Remove the oldest files in Logs folder to keep only a specified number of recent log files.

.DESCRIPTION
This script creates a Task Scheduler XML file (compatible with the Windows Task Scheduler schema) that runs the MailStore
RunAllProfiles batch. It can also register the task using the ScheduledTasks module. The XML is written in UTF-16 LE
to match Task Scheduler export format.

.PARAMETER LogDir
Path to the MailStore Logs directory. Default is C:\MailStore\Logs.

.PARAMETER KeepCount
Number of most recent log files to keep. Default is 100.

.EXAMPLE
PS> .\Remove-OldLogs.ps1 

.EXAMPLE
PS> .\Remove-OldLogs.ps1 -LogDir "D:\CustomLogs" -KeepCount 50

.NOTES
Written for MailStore Home log maintenance.
#>


param(
    [string]$LogDir = "C:\MailStore\Logs",
    [int]$KeepCount = 100
)

# Obtener todos los archivos en el directorio de logs, ordenados por fecha de modificación (más reciente primero)
$files = Get-ChildItem -Path $LogDir -File | Sort-Object LastWriteTime -Descending

# Si hay más de $KeepCount archivos, eliminar los más antiguos
if ($files.Count -gt $KeepCount) {
    $toDelete = $files[$KeepCount..($files.Count - 1)]
    foreach ($file in $toDelete) {
        Remove-Item $file.FullName -Force
    }
}