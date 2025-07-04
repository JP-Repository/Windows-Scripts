<#
.SYNOPSIS
    Exports TeamViewer devices (MDv2) that haven't been online for a given time and sends a report via email.

.DESCRIPTION
    Fetches TeamViewer devices (MDv2) and exports those offline beyond a given expiry date or interval to a CSV, and emails the report with summary.

.PARAMETER ExpiryDate
    Specific cutoff datetime for filtering.

.PARAMETER ExpiryInterval
    Enables interval-based calculation using Days/Hours/etc.

.PARAMETER Days/Hours/Minutes/Seconds
    Time interval used with -ExpiryInterval.

.EXAMPLE
    .\Export-TeamViewerOutdatedDevices.ps1 -ExpiryInterval -Days 10 -WhatIf
#>

[CmdletBinding(DefaultParameterSetName = 'ExactDate')]
param(
    [Parameter(ParameterSetName = 'ExactDate', Mandatory = $true)]
    [DateTime] $ExpiryDate,

    [Parameter(ParameterSetName = 'DateInterval', Mandatory = $true)]
    [switch] $ExpiryInterval,

    [Parameter(ParameterSetName = 'DateInterval')] [int] $Days = 0,
    [Parameter(ParameterSetName = 'DateInterval')] [int] $Hours = 0,
    [Parameter(ParameterSetName = 'DateInterval')] [int] $Minutes = 0,
    [Parameter(ParameterSetName = 'DateInterval')] [int] $Seconds = 0
)

function Get-ApiToken {
    $tokenPath = "$env:USERPROFILE\TeamViewerApiToken.xml"
    if (-not (Test-Path $tokenPath)) {
        Throw "API token file not found at: $tokenPath. Please run `Read-Host 'Enter API Token' -AsSecureString | Export-Clixml -Path '$tokenPath'` first."
    }
    return Import-Clixml -Path $tokenPath
}

# Email configuration
$EmailRecipient = "Email Address" #,"Cognizant-EUC-SCCM@cabotcorp.com"
$SMTPServer = "smtp server address"
$FromEmail = "From Email Address"
$Hostname = $env:COMPUTERNAME
$DateMonth = (Get-Date -Format "MMMM")
$CSVFilePath = "C:\Temp\OutdatedDevices_$((Get-Date).ToString('yyyyMMdd_HHmmss')).csv"

# Load API token
$secureApiToken = Get-ApiToken

# Install TeamViewer module if not already available
if (-not (Get-Module -ListAvailable -Name TeamViewerPS)) {
    Install-Module -Name TeamViewerPS -Force -Scope CurrentUser
}
Import-Module TeamViewerPS

# Calculate expiry date if interval is provided
if ($ExpiryInterval) {
    $now = Get-Date
    $ExpiryDate = $now.AddDays(-1 * $Days).AddHours(-1 * $Hours).AddMinutes(-1 * $Minutes).AddSeconds(-1 * $Seconds)
}

# Ensure expiry date is not in the future
if ($ExpiryDate -ge (Get-Date)) {
    Write-Error "Invalid expiry date specified: $ExpiryDate"
    exit 1
}

# Get and filter devices
try {
    $devices = Get-TeamViewerCompanyManagedDevice -ApiToken $secureApiToken | Where-Object {
        -not $_.IsOnline -and $_.LastSeenAt -and $_.LastSeenAt -le $ExpiryDate
    }
} catch {
    Write-Error "Failed to retrieve devices. $_"
    exit 1
}

# Output to console and CSV
$devices | Select-Object Name, Id, LastSeenAt | Format-Table -AutoSize
$devices | Select-Object Name, Id, LastSeenAt | Export-Csv -Path $CSVFilePath -NoTypeInformation

# Compose log summary for email
$DeviceCount = $devices.Count
$Log = $devices | Select-Object Name, Id, LastSeenAt | Out-String

# Prepare email body
$EmailBody = @"
Hello,

The script has completed its execution. Below is the summary:

- Total Outdated Devices Found: $DeviceCount
- Expiry Cutoff Used: $ExpiryDate

List of devices:
$Log

NOTE: This script is scheduled to run monthly.

Regards,
Automated Script Executed From $Hostname
"@

# Send email with attachment if file exists
if (Test-Path $CSVFilePath) {
    Send-MailMessage -To $EmailRecipient -From $FromEmail -Subject "Outdated TeamViewer Devices Report - $DateMonth" `
        -Body $EmailBody -SmtpServer $SMTPServer -Attachments $CSVFilePath
} else {
    Send-MailMessage -To $EmailRecipient -From $FromEmail -Subject "Outdated TeamViewer Devices Report - $DateMonth" `
        -Body $EmailBody -SmtpServer $SMTPServer
}
