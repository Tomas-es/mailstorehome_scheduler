# Load MailKit and MimeKit

Add-Type -Path $PSScriptRoot\MimeKit.dll
Add-Type -Path $PSScriptRoot\MailKit.dll

# Load configuration from JSON file
$config = Get-Content "ConfigMail.json" | ConvertFrom-Json

$email = $config.email
$destinationEmail = $config.destinationEmail
$smtpServer = $config.smtpServer
$smtpPort = $config.smtpPort
$PasswordPath = $config.PasswordPath

# Create the message
$message = New-Object MimeKit.MimeMessage
$message.From.Add($email)
$message.To.Add($destinationEmail)
$message.Subject = "Hello from PowerShell + MailKit"

$builder = New-Object MimeKit.BodyBuilder
$builder.TextBody = "This is a plain text message."
$builder.HtmlBody = "<h2>This is HTML</h2><p>Sent via MailKit</p>"
$message.Body = $builder.ToMessageBody()

# Send the message
$client = New-Object MailKit.Net.Smtp.SmtpClient
$client.Connect($smtpServer, $smtpPort, [MailKit.Security.SecureSocketOptions]::StartTls)
# Secure modifiation to read password from file
$securePassword = Get-Content -Path $PasswordPath | ConvertTo-SecureString
$credential = New-Object System.Management.Automation.PSCredential ($email, $securePassword)
$client.Authenticate($credential.UserName, $credential.GetNetworkCredential().Password)
$client.Send($message)
$client.Disconnect($true)
$client.Dispose()