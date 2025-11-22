<#
.SYNOPSIS
    Checks the current TLS registry settings (TLS 1.0, 1.1, 1.2) on remote servers
    and generates CSV and HTML reports.

.DESCRIPTION
    This script:
        - Reads a list of remote servers from C:\Temp\ServerList.txt
        - Connects to each server via PowerShell remoting
        - Queries SCHANNEL TLS registry keys for:
              TLS 1.0, TLS 1.1, TLS 1.2
          and roles:
              Client, Server
        - Collects the Enabled and DisabledByDefault registry values (if present)
        - Exports:
              * A CSV report with raw values
              * An HTML report with color-coded Secure / Not Secure / Unknown states
                grouped by server (server name shown once as a header row).

    Output is stored under:
        C:\Temp\TLS Remediation Results

    The HTML report is automatically opened in the default browser at the end.

.NOTES
    Script Name    : Get-TLSVersion_MultipleServers.ps1
    Version        : 1.0
    Author         : [Your Name]
    Approved By    : [Approver's Name]
    Date           : 2025-05-05
    Purpose        : To gather the existing TLS registry configuration on multiple servers
                     for review and TLS hardening validation.

.PREREQUISITES
    - Remote PowerShell access (WinRM) enabled on target servers
    - C:\Temp\ServerList.txt file with one server name per line
    - Necessary permissions to read registry keys remotely
    - Output base folder: C:\Temp
      (The script will create "TLS Remediation Results" under C:\Temp if it does not exist.)

.PARAMETERS
    None

.EXAMPLE
    PS C:\> .\Get-TLSVersion_MultipleServers.ps1 -Verbose

    Runs the script with verbose logging, exports CSV and HTML reports to:
        C:\Temp\TLS Remediation Results\TLS_Check_Result_yyyyMMdd_HHmmss.csv
        C:\Temp\TLS Remediation Results\TLS_Check_Result_yyyyMMdd_HHmmss.html
#>

[CmdletBinding()]
param()

# Start of Script

$serverListPath = "C:\Temp\ServerList.txt"

# Validate server list
if (-not (Test-Path -Path $serverListPath)) {
    Write-Error "Server list file not found: $serverListPath"
    return
}

$servers = Get-Content -Path $serverListPath | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }

if (-not $servers -or $servers.Count -eq 0) {
    Write-Error "Server list file '$serverListPath' is empty or contains only blank lines."
    return
}

$protocols = @("TLS 1.0", "TLS 1.1", "TLS 1.2")
$roles     = @("Client", "Server")
$results   = @()

$totalStart = Get-Date
Write-Verbose "TLS registry check started at $($totalStart.ToString('yyyy-MM-dd HH:mm:ss'))"

# Progress bar variables
$totalServers = $servers.Count
$currentIndex = 0

foreach ($server in $servers) {

    $currentIndex++
    Write-Progress `
        -Activity "Checking TLS Configuration on Remote Servers" `
        -Status "Processing $server ($currentIndex of $totalServers)" `
        -PercentComplete (($currentIndex / $totalServers) * 100)

    $serverStart = Get-Date
    Write-Verbose "------------------------------------------------------------"
    Write-Verbose "Checking server: $server | Start time: $($serverStart.ToString('yyyy-MM-dd HH:mm:ss'))"

    foreach ($protocol in $protocols) {
        foreach ($role in $roles) {
            Write-Verbose "  Checking protocol: $protocol ($role)"
            $regPath = "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\$protocol\$role"
            try {
                $output = Invoke-Command -ComputerName $server -ScriptBlock {
                    param ($path)
                    $enabled  = $null
                    $disabled = $null
                    if (Test-Path $path) {
                        $enabled = Get-ItemProperty -Path $path -Name Enabled -ErrorAction SilentlyContinue |
                                   Select-Object -ExpandProperty Enabled -ErrorAction SilentlyContinue
                        $disabled = Get-ItemProperty -Path $path -Name DisabledByDefault -ErrorAction SilentlyContinue |
                                    Select-Object -ExpandProperty DisabledByDefault -ErrorAction SilentlyContinue
                    }
                    return [PSCustomObject]@{
                        Enabled           = $enabled
                        DisabledByDefault = $disabled
                    }
                } -ArgumentList $regPath -ErrorAction Stop

                $results += [PSCustomObject]@{
                    ComputerName      = $server
                    Protocol          = $protocol
                    Role              = $role
                    Enabled           = $output.Enabled
                    DisabledByDefault = $output.DisabledByDefault
                }
            }
            catch {
                Write-Verbose "  Error connecting to $server or reading $protocol ($role)"
                $results += [PSCustomObject]@{
                    ComputerName      = $server
                    Protocol          = $protocol
                    Role              = $role
                    Enabled           = "Error"
                    DisabledByDefault = "Error"
                }
            }
        }
    }

    $serverEnd = Get-Date
    $duration  = New-TimeSpan -Start $serverStart -End $serverEnd
    Write-Verbose "Finished checking server: $server | End time: $($serverEnd.ToString('yyyy-MM-dd HH:mm:ss')) | Duration: $($duration.ToString())"
}

$totalEnd      = Get-Date
$totalDuration = New-TimeSpan -Start $totalStart -End $totalEnd
Write-Verbose "------------------------------------------------------------"
Write-Verbose "All servers checked. Total duration: $($totalDuration.ToString())"

# ---------- Output folder & file paths ----------
$basePath = "C:\Temp\TLS Remediation Results"
New-Item -Path $basePath -ItemType Directory -Force -ErrorAction SilentlyContinue | Out-Null

$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$csvPath   = Join-Path $basePath "TLS_Check_Result_$timestamp.csv"
$htmlPath  = Join-Path $basePath "TLS_Check_Result_$timestamp.html"

# Export CSV
$results | Export-Csv -NoTypeInformation -Path $csvPath
Write-Verbose "CSV results exported to $csvPath"

# ---------- Build HTML report (grouped by server) ----------

$generatedOn = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

$htmlHeader = @"
<!DOCTYPE html>
<html>
<head>
    <meta charset="utf-8" />
    <title>Servers TLS Configuration Report</title>
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
            white-space: nowrap;
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
        <h1>Servers TLS Configuration Report</h1>
        <div class="subtitle">Summary of SCHANNEL TLS registry settings across all listed servers</div>
        <div class="meta">
            Generated on: $generatedOn<br />
            Server list file: $serverListPath
        </div>

        <div class="legend">
            <strong>Legend:</strong>
            <span><span class="badge status-secure">Secure</span> TLS 1.2 enabled, older protocols disabled (expected state)</span>
            <span><span class="badge status-insecure">Not Secure</span> Insecure / legacy protocol enabled or TLS 1.2 missing</span>
            <span><span class="badge status-unknown">Unknown</span> Registry keys missing or error reading values</span>
        </div>

        <table>
            <thead>
                <tr>
                    <th>Server</th>
                    <th>Protocol</th>
                    <th>Role</th>
                    <th>Enabled</th>
                    <th>DisabledByDefault</th>
                    <th class="center">State</th>
                    <th>Notes</th>
                </tr>
            </thead>
            <tbody>
"@

$htmlRows = ""

# Group results by server so name appears once as a header row
$serversGrouped = $results | Group-Object ComputerName

foreach ($serverGroup in $serversGrouped) {

    $serverName = $serverGroup.Name

    # Server header row spanning all columns
    $htmlRows += @"
                <tr style='background-color:#e8e8e8; font-weight:bold;'>
                    <td colspan='7'>$serverName</td>
                </tr>
"@

    foreach ($row in $serverGroup.Group) {

        $protocol = $row.Protocol
        $role     = $row.Role
        $enabled  = $row.Enabled
        $disabled = $row.DisabledByDefault

        $enabledDisplay  = if ($null -eq $enabled  -or $enabled  -eq "") { "N/A" } else { "$enabled" }
        $disabledDisplay = if ($null -eq $disabled -or $disabled -eq "") { "N/A" } else { "$disabled" }

        $enabledClass  = if ($enabledDisplay  -eq "N/A") { "value-null" } else { "" }
        $disabledClass = if ($disabledDisplay -eq "N/A") { "value-null" } else { "" }

        # Default state
        $stateClass = "status-unknown"
        $stateText  = "Unknown"
        $notes      = "Key missing, not set, or error reading values."

        if ($enabledDisplay -eq "Error" -or $disabledDisplay -eq "Error") {
            $stateClass = "status-unknown"
            $stateText  = "Unknown"
            $notes      = "Error reading registry values on this server."
        }
        else {
            $enabledNumeric  = $null
            $disabledNumeric = $null
            [void][int]::TryParse("$enabledDisplay",  [ref]$enabledNumeric)
            [void][int]::TryParse("$disabledDisplay", [ref]$disabledNumeric)

            if ($enabledDisplay -ne "N/A" -or $disabledDisplay -ne "N/A") {
                if ($protocol -eq "TLS 1.2") {
                    # Secure if TLS 1.2 is properly enabled (Enabled=1, DisabledByDefault=0)
                    if ($enabledNumeric -eq 1 -and $disabledNumeric -eq 0) {
                        $stateClass = "status-secure"
                        $stateText  = "Secure"
                        $notes      = "Expected modern protocol configuration (TLS 1.2 enabled)."
                    }
                    else {
                        $stateClass = "status-insecure"
                        $stateText  = "Not Secure"
                        $notes      = "TLS 1.2 not configured as expected."
                    }
                }
                elseif ($protocol -in @("TLS 1.0", "TLS 1.1")) {
                    # Secure if legacy TLS is disabled (Enabled=0, DisabledByDefault=1)
                    if ($enabledNumeric -eq 0 -and $disabledNumeric -eq 1) {
                        $stateClass = "status-secure"
                        $stateText  = "Secure"
                        $notes      = "Legacy protocol disabled for this role."
                    }
                    else {
                        $stateClass = "status-insecure"
                        $stateText  = "Not Secure"
                        $notes      = "Legacy protocol still enabled or not fully disabled."
                    }
                }
            }
        }

        # Detail row (first column blank because server is shown in header row)
        $htmlRows += @"
                <tr>
                    <td></td>
                    <td>$protocol</td>
                    <td>$role</td>
                    <td class="$enabledClass">$enabledDisplay</td>
                    <td class="$disabledClass">$disabledDisplay</td>
                    <td class="center"><span class="badge $stateClass">$stateText</span></td>
                    <td>$notes</td>
                </tr>
"@
    }
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
Write-Verbose "HTML report exported to $htmlPath"

# Open HTML report automatically
Start-Process $htmlPath

# End of Script
