<#
.SYNOPSIS
    Checks local server .NET and SCHANNEL TLS registry settings (TLS 1.0, 1.1, 1.2, 1.3)
    and generates CSV and HTML reports.

.DESCRIPTION
    This script reads key registry values related to:
        - .NET Framework strong crypto / default TLS behavior
        - SCHANNEL TLS protocol enablement (Client and Server roles for TLS 1.0–1.3)

    It uses a helper function (Get-RegValue) to safely query individual registry paths and values,
    returning "Not Found" if the value does not exist.

    Output:
        - Console: collection of objects (Path, Name, Value)
        - CSV:     saved under C:\Temp\TLS Remediation Results\
        - HTML:    formatted report with Secure / Not Secure / Unknown states
                   saved under the same folder and opened automatically.

.NOTES
    Script Name    : Get-Local_TLS_DotNet_RegSettings.ps1
    Version        : 1.1
    Author         : [Your Name]
    Approved By    : [Approver's Name]
    Date           : [Date]
    Purpose        : Quickly capture local TLS-related registry configuration for .NET and SCHANNEL
                     to assist with TLS hardening assessments or troubleshooting, and present it in
                     both CSV and human-readable HTML format.

.PREREQUISITES
    - Run with administrative privileges (recommended for registry access).
    - Supported on Windows systems with the relevant .NET and SCHANNEL registry paths.
    - Output base folder: C:\Temp
      (The script will create "TLS Remediation Results" under C:\Temp if it does not exist.)

.PARAMETERS
    None
        This script has no parameters and runs against the local machine.
        The output is a collection of objects with:
            - Path
            - Name
            - Value

.EXAMPLE
    PS C:\> .\Get-Local_TLS_DotNet_RegSettings.ps1

    Runs the script on the local machine, outputs a list of registry paths, names, and values,
    and generates CSV and HTML reports in:
        C:\Temp\TLS Remediation Results\

.EXAMPLE
    PS C:\> .\Get-Local_TLS_DotNet_RegSettings.ps1 | Format-Table -AutoSize

    Displays the output in a formatted table (in addition to the generated reports).
#>

# Start of Script

function Get-RegValue {
    [CmdletBinding()]
    Param
    (
        # Registry Path
        [Parameter(Mandatory = $true, Position = 0)]
        [string]
        $RegPath,

        # Registry Name
        [Parameter(Mandatory = $true, Position = 1)]
        [string]
        $RegName
    )

    $regItem = Get-ItemProperty -Path $RegPath -Name $RegName -ErrorAction Ignore
    $output  = "" | Select-Object Path, Name, Value
    $output.Path = $RegPath
    $output.Name = $RegName

    if ($null -eq $regItem) {
        $output.Value = "Not Found"
    }
    else {
        $output.Value = $regItem.$RegName
    }

    $output
}

$regSettings = @()

# .NET Framework v4 (64-bit)
$regKey = 'HKLM:\SOFTWARE\Microsoft\.NETFramework\v4.0.30319'
$regSettings += Get-RegValue $regKey 'SystemDefaultTlsVersions'
$regSettings += Get-RegValue $regKey 'SchUseStrongCrypto'

# .NET Framework v4 (32-bit / WOW6432Node)
$regKey = 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\.NETFramework\v4.0.30319'
$regSettings += Get-RegValue $regKey 'SystemDefaultTlsVersions'
$regSettings += Get-RegValue $regKey 'SchUseStrongCrypto'

# .NET Framework v2 (64-bit)
$regKey = 'HKLM:\SOFTWARE\Microsoft\.NETFramework\v2.0.50727'
$regSettings += Get-RegValue $regKey 'SystemDefaultTlsVersions'
$regSettings += Get-RegValue $regKey 'SchUseStrongCrypto'

# .NET Framework v2 (32-bit / WOW6432Node)
$regKey = 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\.NETFramework\v2.0.50727'
$regSettings += Get-RegValue $regKey 'SystemDefaultTlsVersions'
$regSettings += Get-RegValue $regKey 'SchUseStrongCrypto'

# TLS 1.3 - Server
$regKey = 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.3\Server'
$regSettings += Get-RegValue $regKey 'Enabled'
$regSettings += Get-RegValue $regKey 'DisabledByDefault'

# TLS 1.3 - Client
$regKey = 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.3\Client'
$regSettings += Get-RegValue $regKey 'Enabled'
$regSettings += Get-RegValue $regKey 'DisabledByDefault'

# TLS 1.2 - Server
$regKey = 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.2\Server'
$regSettings += Get-RegValue $regKey 'Enabled'
$regSettings += Get-RegValue $regKey 'DisabledByDefault'

# TLS 1.2 - Client
$regKey = 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.2\Client'
$regSettings += Get-RegValue $regKey 'Enabled'
$regSettings += Get-RegValue $regKey 'DisabledByDefault'

# TLS 1.1 - Server
$regKey = 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.1\Server'
$regSettings += Get-RegValue $regKey 'Enabled'
$regSettings += Get-RegValue $regKey 'DisabledByDefault'

# TLS 1.1 - Client
$regKey = 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.1\Client'
$regSettings += Get-RegValue $regKey 'Enabled'
$regSettings += Get-RegValue $regKey 'DisabledByDefault'

# TLS 1.0 - Server
$regKey = 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.0\Server'
$regSettings += Get-RegValue $regKey 'Enabled'
$regSettings += Get-RegValue $regKey 'DisabledByDefault'

# TLS 1.0 - Client
$regKey = 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.0\Client'
$regSettings += Get-RegValue $regKey 'Enabled'
$regSettings += Get-RegValue $regKey 'DisabledByDefault'

# --------- Output Folder & File Paths ---------
$basePath = "C:\Temp\TLS Remediation Results"
New-Item -Path $basePath -ItemType Directory -Force -ErrorAction SilentlyContinue | Out-Null

$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$csvPath   = Join-Path $basePath "Local_TLS_RegSettings_$timestamp.csv"
$htmlPath  = Join-Path $basePath "Local_TLS_RegSettings_$timestamp.html"

# Export CSV
$regSettings | Export-Csv -NoTypeInformation -Path $csvPath

# --------- Build HTML Report ---------

$computerName = $env:COMPUTERNAME
$generatedOn  = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

$htmlHeader = @"
<!DOCTYPE html>
<html>
<head>
    <meta charset="utf-8" />
    <title>Local TLS & .NET Registry Configuration Report</title>
    <style>
        body {
            font-family: Segoe UI, Arial, sans-serif;
            background-color: #f5f5f5;
            margin: 0;
            padding: 20px;
        }
        .report-container {
            max-width: 1200px;
            margin: 0 auto;
            background-color: #ffffff;
            border-radius: 8px;
            padding: 20px 24px;
            box-shadow: 0 2px 6px rgba(0,0,0,0.1);
        }
        h1 {
            font-size: 22px;
            margin-bottom: 4px;
        }
        .subtitle {
            color: #555;
            font-size: 13px;
            margin-bottom: 16px;
        }
        .meta {
            font-size: 12px;
            color: #777;
            margin-bottom: 16px;
        }
        .legend {
            font-size: 12px;
            margin-bottom: 16px;
        }
        .legend span {
            display: inline-block;
            margin-right: 12px;
        }
        .badge {
            display: inline-block;
            padding: 2px 8px;
            font-size: 11px;
            border-radius: 10px;
            font-weight: 600;
        }
        .status-secure {
            background-color: #d4edda;
            color: #155724;
        }
        .status-insecure {
            background-color: #f8d7da;
            color: #721c24;
        }
        .status-unknown {
            background-color: #e2e3e5;
            color: #383d41;
        }
        table {
            width: 100%;
            border-collapse: collapse;
            font-size: 12px;
        }
        thead {
            background-color: #f0f0f0;
        }
        th, td {
            padding: 8px 10px;
            border-bottom: 1px solid #e0e0e0;
            text-align: left;
        }
        th {
            font-weight: 600;
            font-size: 12px;
        }
        tbody tr:nth-child(even) {
            background-color: #fafafa;
        }
        .center {
            text-align: center;
        }
        .value-null {
            color: #999;
            font-style: italic;
        }
    </style>
</head>
<body>
    <div class="report-container">
        <h1>Local TLS & .NET Registry Configuration Report</h1>
        <div class="subtitle">Summary of TLS- and .NET-related registry keys on the local server</div>
        <div class="meta">
            Computer: $computerName<br />
            Generated on: $generatedOn<br />
        </div>

        <div class="legend">
            <strong>Legend:</strong>
            <span><span class="badge status-secure">Secure</span> Recommended / hardened configuration</span>
            <span><span class="badge status-insecure">Not Secure</span> Legacy / weak or non-recommended value</span>
            <span><span class="badge status-unknown">Unknown</span> Registry value missing or not evaluated</span>
        </div>

        <table>
            <thead>
                <tr>
                    <th>Registry Path</th>
                    <th>Name</th>
                    <th>Value</th>
                    <th class="center">State</th>
                    <th>Notes</th>
                </tr>
            </thead>
            <tbody>
"@

$htmlRows = ""

foreach ($row in $regSettings) {
    $path  = $row.Path
    $name  = $row.Name
    $value = $row.Value

    $valueDisplay = if ($null -eq $value -or $value -eq "") { "N/A" } else { "$value" }
    $valueClass   = if ($valueDisplay -eq "N/A" -or $valueDisplay -eq "Not Found") { "value-null" } else { "" }

    # Defaults
    $stateClass = "status-unknown"
    $stateText  = "Unknown"
    $notes      = "Value not found or not evaluated."

    if ($valueDisplay -eq "Not Found" -or $valueDisplay -eq "N/A") {
        $stateClass = "status-unknown"
        $stateText  = "Unknown"
        $notes      = "Registry value not found."
    }
    else {
        # Try to treat as integer where applicable
        $valueNumeric = $null
        [void][int]::TryParse($valueDisplay, [ref]$valueNumeric)

        # .NET Framework settings
        if ($path -like '*\Microsoft\.NETFramework\*' -and ($name -eq 'SystemDefaultTlsVersions' -or $name -eq 'SchUseStrongCrypto')) {
            # Best practice: these should be 1
            if ($valueNumeric -eq 1) {
                $stateClass = "status-secure"
                $stateText  = "Secure"
                $notes      = ".NET $name is enabled (value=1)."
            }
            else {
                $stateClass = "status-insecure"
                $stateText  = "Not Secure"
                $notes      = ".NET $name is not set to 1 (recommended)."
            }
        }
        # SCHANNEL: TLS 1.2 / 1.3
        elseif ($path -like '*\Protocols\TLS 1.2\*' -or $path -like '*\Protocols\TLS 1.3\*') {
            if ($name -eq 'Enabled') {
                # Recommended: Enabled = 1
                if ($valueNumeric -eq 1) {
                    $stateClass = "status-secure"
                    $stateText  = "Secure"
                    $notes      = "$name is correctly set to 1 for a modern protocol."
                }
                else {
                    $stateClass = "status-insecure"
                    $stateText  = "Not Secure"
                    $notes      = "$name is not set to 1 for a modern protocol."
                }
            }
            elseif ($name -eq 'DisabledByDefault') {
                # Recommended: DisabledByDefault = 0
                if ($valueNumeric -eq 0) {
                    $stateClass = "status-secure"
                    $stateText  = "Secure"
                    $notes      = "$name is correctly set to 0 for a modern protocol."
                }
                else {
                    $stateClass = "status-insecure"
                    $stateText  = "Not Secure"
                    $notes      = "$name is not set to 0 for a modern protocol."
                }
            }
        }
        # SCHANNEL: TLS 1.0 / 1.1 (legacy protocols)
        elseif ($path -like '*\Protocols\TLS 1.0\*' -or $path -like '*\Protocols\TLS 1.1\*') {
            if ($name -eq 'Enabled') {
                # Recommended: legacy TLS disabled (Enabled = 0)
                if ($valueNumeric -eq 0) {
                    $stateClass = "status-secure"
                    $stateText  = "Secure"
                    $notes      = "Legacy protocol is disabled (Enabled=0)."
                }
                else {
                    $stateClass = "status-insecure"
                    $stateText  = "Not Secure"
                    $notes      = "Legacy protocol is still enabled (Enabled<>0)."
                }
            }
            elseif ($name -eq 'DisabledByDefault') {
                # Recommended: legacy TLS disabled by default (1)
                if ($valueNumeric -eq 1) {
                    $stateClass = "status-secure"
                    $stateText  = "Secure"
                    $notes      = "Legacy protocol disabled by default (DisabledByDefault=1)."
                }
                else {
                    $stateClass = "status-insecure"
                    $stateText  = "Not Secure"
                    $notes      = "Legacy protocol not disabled by default (DisabledByDefault<>1)."
                }
            }
        }
    }

    $htmlRows += @"
                <tr>
                    <td>$path</td>
                    <td>$name</td>
                    <td class="$valueClass">$valueDisplay</td>
                    <td class="center"><span class="badge $stateClass">$stateText</span></td>
                    <td>$notes</td>
                </tr>
"@
}

$htmlFooter = @"
            </tbody>
        </table>
    </div>
</body>
</html>
"@

$htmlContent = $htmlHeader + $htmlRows + $htmlFooter

Set-Content -Path $htmlPath -Value $htmlContent -Encoding UTF8

# Open HTML report automatically
Start-Process $htmlPath

# Still output to console
$regSettings

# End of Script
