param (
    [string]$ProfileName,
    [string]$Result,
    [string]$LogFile
)


# === Load encrypted password ===
$SecurePassword = Get-Content "C:\MailStore\smtp_password.txt" | ConvertTo-SecureString
$Credential = New-Object System.Management.Automation.PSCredential ($Username, $SecurePassword)

# === Build body ===
$Body = Get-Content -Path $LogFile | Out-String

# === Email settings ===
$sendMailMessageSplat = @{
    From = 'User01 <user01@fabrikam.com>'
    To = 'User02 <user02@fabrikam.com>', 'User03 <user03@fabrikam.com>'
    Subject = "MailStore - $ProfileName - $Result"
    Body = $Body
    BodyAsHtml = $false
    Attachments = $LogFile
    Credential = $Credential
    $SMTPServer = 'smtp.fabrikam.com'
    $SMTPPort = 587
    UseSsl = $true
    $Username = 'user01@fabrikam.com'
}


try {
    Send-MailMessage @sendMailMessageSplat
    Write-Output "Email sent successfully for $ProfileName"
}
catch {
    Write-Output "Email failed for ${ProfileName}: $_"
}
