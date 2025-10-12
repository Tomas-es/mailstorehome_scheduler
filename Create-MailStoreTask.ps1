<#
.SYNOPSIS
Generates a Task Scheduler XML for MailStore RunAllProfiles and optionally registers the task.

.DESCRIPTION
This script creates a Task Scheduler XML file (compatible with the Windows Task Scheduler schema) that runs the MailStore
RunAllProfiles batch. It can also register the task using the ScheduledTasks module. The XML is written in UTF-16 LE
to match Task Scheduler export format.

.PARAMETER UserId
The account (domain\user or machine\user) that will be recorded as the Author and used as the principal for the task.
Defaults to the current interactive user.

.PARAMETER BatchPath
Full path to the batch file that the task will execute. Example: C:\MailStore\RunAllProfiles.bat

.PARAMETER OutXml
Path where the generated task XML will be written. If omitted the script writes mailstore_runallprofiles.xml next to BatchPath.

.PARAMETER Start1
Date/time for the first daily trigger. Accepts any value that can be parsed by [DateTime]. If omitted the default is tomorrow at 05:00.

.PARAMETER Start2
Date/time for the second daily trigger. If omitted the default is tomorrow at 14:15.

.PARAMETER StartBoundary
A single StartBoundary value used as a fallback if Start1/Start2 are not provided.

.PARAMETER RegistrationDate
Date to set in the RegistrationInfo section of the XML. Defaults to the current date/time.

.PARAMETER LogonType
Task principal LogonType. Valid values are the Task Scheduler enum names: None, Password, S4U, Interactive, Group, ServiceAccount, InteractiveOrPassword. Default: Interactive.

.PARAMETER RunLevel
Task RunLevel, either LeastPrivilege or HighestAvailable. Default: LeastPrivilege.

.PARAMETER TaskName
Name to use when registering the Scheduled Task (only used when -Register is specified).

.PARAMETER Register
If present the script will attempt to register the generated task using Register-ScheduledTask. Requires appropriate privileges.

.PARAMETER Force
When registering, replace any existing task with the same name.

.EXAMPLE
PS> .\Create-MailStoreTask.ps1 -UserId 'MYPC\\me' -Register -Force

.NOTES
Written for compatibility with Windows PowerShell 5.1. The script avoids PowerShell 7-only syntax.
#>

[CmdletBinding()]
param(
    [string]$UserId = "$env:COMPUTERNAME\$env:USERNAME",
    [string]$BatchPath = 'C:\MailStore\RunAllProfiles.bat',
    [string]$OutXml = '',
  [string]$StartBoundary = '',
  [string]$Start1 = '',
  [string]$Start2 = '',
    [string]$RegistrationDate = '',
  [ValidateSet('None','Password','S4U','Interactive','Group','ServiceAccount','InteractiveOrPassword')][string]$LogonType = 'Interactive',
    [ValidateSet('LeastPrivilege','HighestAvailable')][string]$RunLevel = 'LeastPrivilege',
    [string]$TaskName = 'MailStore RunAllProfiles',
    [switch]$Register,
    [switch]$Force
)
# To do: You call this function many times. Improve with error handling.
function Format-DateForTask([DateTime]$dt){
    return $dt.ToString('yyyy-MM-ddTHH:mm:ss')
}

# Normalize paths and defaults
$BatchPath = (Resolve-Path -Path $BatchPath -ErrorAction SilentlyContinue) -as [string]
if (-not $BatchPath){
    throw "Batch file not found. Provide a valid -BatchPath"
}

if ([string]::IsNullOrWhiteSpace($OutXml)){
    $OutXml = Join-Path -Path (Split-Path -Parent $BatchPath) -ChildPath 'mailstore_runallprofiles.xml'
}

$now = Get-Date
if ([string]::IsNullOrWhiteSpace($RegistrationDate)){
    $regDate = Format-DateForTask $now
} else {
  # Todo: Include in Format-DateForTask error handling
    $parsedDate = $null
    if ([DateTime]::TryParse($RegistrationDate, [ref]$parsedDate)) {
        $regDate = Format-DateForTask $parsedDate
    } else {
        Write-Warning "Invalid RegistrationDate provided. Using current date/time."
        $regDate = Format-DateForTask $now
    }
}

if (-not [string]::IsNullOrWhiteSpace($Start1)){
  $start1 = [DateTime]$Start1
} elseif (-not [string]::IsNullOrWhiteSpace($StartBoundary)){
  $start1 = [DateTime]$StartBoundary
} else {
  # Default to tomorrow at 05:00
  $start1 = $now.Date.AddDays(1).AddHours(5)
}

if (-not [string]::IsNullOrWhiteSpace($Start2)){
  $start2 = [DateTime]$Start2
} elseif (-not [string]::IsNullOrWhiteSpace($StartBoundary)){
  $start2 = [DateTime]$StartBoundary
} else {
  # Default to tomorrow at 14:15
  $start2 = $now.Date.AddDays(1).AddHours(14).AddMinutes(15)
}

$startBoundary1 = Format-DateForTask $start1
$startBoundary2 = Format-DateForTask $start2

Write-Host "Generating task XML for user: $UserId"
Write-Host "StartBoundaries: $startBoundary1 , $startBoundary2    RegistrationDate: $regDate"

$xml = @"
<?xml version="1.0" encoding="UTF-16"?>
<Task version="1.4" xmlns="http://schemas.microsoft.com/windows/2004/02/mit/task">
  <RegistrationInfo>
    <Date>$regDate</Date>
    <Author>$UserId</Author>
    <Description>Runs all MailStore Home archive profiles sequentially.</Description>
  </RegistrationInfo>
  <Triggers>
    <CalendarTrigger>
      <StartBoundary>$startBoundary1</StartBoundary>
      <Enabled>true</Enabled>
      <ScheduleByDay>
        <DaysInterval>1</DaysInterval>
      </ScheduleByDay>
    </CalendarTrigger>
    <CalendarTrigger>
      <StartBoundary>$startBoundary2</StartBoundary>
      <Enabled>true</Enabled>
      <ScheduleByDay>
        <DaysInterval>1</DaysInterval>
      </ScheduleByDay>
    </CalendarTrigger>
  </Triggers>
  <Principals>
    <Principal id="Author">
      <UserId>$UserId</UserId>
      <LogonType>$LogonType</LogonType>
      <RunLevel>$RunLevel</RunLevel>
    </Principal>
  </Principals>
  <Settings>
    <MultipleInstancesPolicy>IgnoreNew</MultipleInstancesPolicy>
    <DisallowStartIfOnBatteries>false</DisallowStartIfOnBatteries>
    <StopIfGoingOnBatteries>false</StopIfGoingOnBatteries>
    <AllowHardTerminate>true</AllowHardTerminate>
  <StartWhenAvailable>false</StartWhenAvailable>
    <RunOnlyIfNetworkAvailable>false</RunOnlyIfNetworkAvailable>
    <IdleSettings>
      <StopOnIdleEnd>false</StopOnIdleEnd>
      <RestartOnIdle>false</RestartOnIdle>
    </IdleSettings>
    <AllowStartOnDemand>true</AllowStartOnDemand>
    <Enabled>true</Enabled>
    <Hidden>false</Hidden>
    <RunOnlyIfIdle>false</RunOnlyIfIdle>
    <DisallowStartOnRemoteAppSession>false</DisallowStartOnRemoteAppSession>
    <UseUnifiedSchedulingEngine>true</UseUnifiedSchedulingEngine>
  <WakeToRun>true</WakeToRun>
    <ExecutionTimeLimit>PT2H</ExecutionTimeLimit>
    <Priority>7</Priority>
  </Settings>
  <Actions Context="Author">
    <Exec>
        <Command>"$BatchPath"</Command>
        <WorkingDirectory>"$(Split-Path -Parent $BatchPath)\"</WorkingDirectory>
    </Exec>
  </Actions>
</Task>
"@

# Write out as Unicode (UTF-16 LE) like the original
[System.IO.File]::WriteAllText($OutXml, $xml, [System.Text.Encoding]::Unicode)
Write-Host "Wrote task XML to: $OutXml"

if ($Register){
    Write-Host "Registering task: $TaskName"
    try{
  $action = New-ScheduledTaskAction -Execute $BatchPath -WorkingDirectory (Split-Path -Parent $BatchPath)
  $time1 = '{0:HH:mm}' -f $start1
  $time2 = '{0:HH:mm}' -f $start2
  $trigger1 = New-ScheduledTaskTrigger -Daily -At $time1
  $trigger2 = New-ScheduledTaskTrigger -Daily -At $time2
  if ($RunLevel -eq 'HighestAvailable') {
    $runLevelValue = 'Highest'
  } else {
    # ScheduledTasks RunLevel enum uses 'Limited' for least-privilege
    $runLevelValue = 'Limited'
  }
  $principal = New-ScheduledTaskPrincipal -UserId $UserId -LogonType $LogonType -RunLevel $runLevelValue
  $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -WakeToRun -ExecutionTimeLimit (New-TimeSpan -Hours 2)

  $task = New-ScheduledTask -Action $action -Trigger $trigger1,$trigger2 -Principal $principal -Settings $settings -Description "Runs all MailStore Home archive profiles sequentially."

        if (Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue){
            if ($Force){
                Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false -ErrorAction Stop
                Register-ScheduledTask -TaskName $TaskName -InputObject $task -ErrorAction Stop
                Write-Host "Replaced existing task: $TaskName"
            } else {
                Write-Host "Task '$TaskName' already exists. Use -Force to replace it."
            }
        } else {
            Register-ScheduledTask -TaskName $TaskName -InputObject $task -ErrorAction Stop
            Write-Host "Registered task: $TaskName"
        }
    } catch {
        Write-Error "Failed to register task: $_"
    }
}
