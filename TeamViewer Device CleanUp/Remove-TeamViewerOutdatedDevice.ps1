<#
.SYNOPSIS
    Removes TeamViewer devices (MDv2) that didn't appear online for a given time.

.DESCRIPTION
    Fetches TeamViewer devices (MDv2) and removes those offline beyond a given expiry date or interval.

.PARAMETER ExpiryDate
    Specific cutoff datetime for removal.

.PARAMETER ExpiryInterval
    Enables interval-based calculation using Days/Hours/etc.

.PARAMETER Days/Hours/Minutes/Seconds
    Time interval used with -ExpiryInterval.

.PARAMETER Force
    If set, bypasses confirmation.

.EXAMPLE
    .\Remove-TeamViewerOutdatedDevice.ps1 -ExpiryInterval -Days 10 -WhatIf

.NOTES
    Requires saved API token:
    Read-Host "Enter TeamViewer API Token" -AsSecureString | Export-Clixml -Path "$env:USERPROFILE\TeamViewerApiToken.xml"
#>

[CmdletBinding(DefaultParameterSetName = 'ExactDate', SupportsShouldProcess = $true)]
param(
    [Parameter(ParameterSetName = 'ExactDate', Mandatory = $true)]
    [DateTime] $ExpiryDate,

    [Parameter(ParameterSetName = 'DateInterval', Mandatory = $true)]
    [switch] $ExpiryInterval,

    [Parameter(ParameterSetName = 'DateInterval')] [int] $Days,
    [Parameter(ParameterSetName = 'DateInterval')] [int] $Hours,
    [Parameter(ParameterSetName = 'DateInterval')] [int] $Minutes,
    [Parameter(ParameterSetName = 'DateInterval')] [int] $Seconds,

    [Switch] $Force = $false
)

if (-Not $MyInvocation.BoundParameters.ContainsKey('ErrorAction')) {
    $script:ErrorActionPreference = 'Stop'
}
if (-Not $MyInvocation.BoundParameters.ContainsKey('InformationAction')) {
    $script:InformationPreference = 'Continue'
}

function Get-ApiToken {
    $tokenPath = "C:\Temp\TeamViewerApiToken.xml"
    if (-not (Test-Path $tokenPath)) {
        Throw "API token file not found at: $tokenPath. Please run `Read-Host 'Enter API Token' -AsSecureString | Export-Clixml -Path '$tokenPath'` first."
    }
    return Import-Clixml -Path $tokenPath
}

function Remove-TeamViewerOutdatedDeviceV2 {
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    param($expiryDate, [securestring]$ApiToken, [bool]$force)

    $devices = @((Get-TeamViewerCompanyManagedDevice -ApiToken $ApiToken) | Where-Object {
        !$_.IsOnline -and $_.LastSeenAt -and $_.LastSeenAt -le $expiryDate
    })

    Write-Information "Found $($devices.Count) devices offline since $expiryDate"

    if ($devices.Count -gt 0 -and -not $WhatIfPreference -and -not $force -and -not $PSCmdlet.ShouldContinue('Do you really want to remove those devices?', $devices)) {
        Write-Information 'Aborting...'
        exit
    }

    foreach ($device in $devices) {
        $status = 'Unchanged'

        if ($force -or $PSCmdlet.ShouldProcess($device.Name)) {
            try {
                Remove-TeamViewerManagedDeviceManagement -ApiToken $ApiToken -Device $device
                $status = 'Removed'
            } catch {
                Write-Warning "Failed to remove device '$($device.Name)': $_"
                $status = 'Failed'
            }
        }

        Write-Host "[$status] $($device.Name) - Last Seen: $($device.LastSeenAt)"
    }
}

# === Script Execution ===
if ($MyInvocation.InvocationName -ne '.') {
    #Install-TeamViewerModule

    $ApiToken = Get-ApiToken
    $now = Get-Date

    if ($ExpiryInterval) {
        $ExpiryDate = $now.AddDays(-1 * $Days).AddHours(-1 * $Hours).AddMinutes(-1 * $Minutes).AddSeconds(-1 * $Seconds)
    }

    if ($ExpiryDate -ge $now) {
        throw "Invalid expiry date specified: $ExpiryDate"
    }

    Remove-TeamViewerOutdatedDeviceV2 -expiryDate $ExpiryDate -ApiToken $ApiToken -force $Force
}
