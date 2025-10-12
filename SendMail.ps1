param (
    [string]$ProfileName,
    [string]$Result,
    [string]$LogFile
)

# === Email settings ===
$From = "mailstore@yourdomain.com"
$To = "you@yourdomain.com"
$Subject = "MailStore - $ProfileName - $Result"
$SMTPServer = "smtp.yourmailserver.com"
$SMTPPort = 587
$Username = "mailstore@yourdomain.com"

# === Load encrypted password ===
$SecurePassword = Get-Content "C:\MailStore\smtp_password.txt" | ConvertTo-SecureString
$Credential = New-Object System.Management.Automation.PSCredential ($Username, $SecurePassword)

# === Build body ===
$Body = Get-Content -Path $LogFile | Out-String

try {
    Send-MailMessage -From $From -To $To -Subject $Subject `
        -SmtpServer $SMTPServer -Port $SMTPPort -UseSsl `
        -Credential $Credential -Body $Body
    Write-Output "Email sent successfully for $ProfileName"
}
catch {
    Write-Output "Email failed for ${ProfileName}: $_"
}
