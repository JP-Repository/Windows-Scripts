<#
.SYNOPSIS
    Checks the current TLS registry settings (TLS 1.0, 1.1, 1.2) on remote servers.

.DESCRIPTION
    This script connects to each server listed in 'ServerList.txt' and queries the registry for SCHANNEL TLS settings.
    It retrieves the 'Enabled' and 'DisabledByDefault' values under each protocol and outputs the result to a CSV file.

.NOTES
    Script Name    : TLS_Version_Check.ps1
    Version        : 1.1
    Author         : [Your Name]
    Approved By    : [Approver's Name]
    Date           : 2025-05-05
    Purpose        : To gather the existing TLS registry configuration on multiple servers for review.

.PREREQUISITES
    - Remote PowerShell access enabled on target servers
    - ServerList.txt file with one server name per line
    - Necessary permissions to read registry keys remotely

.PARAMETERS
    None

.EXAMPLE
    .\TLS_Check.ps1 -Verbose

#>

[CmdletBinding()]
param()

# Start of Script

$servers = Get-Content "C:\Temp\ServerList.txt"
$protocols = @("TLS 1.0", "TLS 1.1", "TLS 1.2")
$roles = @("Client", "Server")
$results = @()

foreach ($server in $servers) {
    Write-Verbose "Checking server: $server"
    foreach ($protocol in $protocols) {
        foreach ($role in $roles) {
            Write-Verbose "  Checking protocol: $protocol ($role)"
            $regPath = "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\$protocol\$role"
            try {
                $output = Invoke-Command -ComputerName $server -ScriptBlock {
                    param ($path)
                    $enabled = $null
                    $disabled = $null
                    if (Test-Path $path) {
                        $enabled = Get-ItemProperty -Path $path -Name Enabled -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Enabled -ErrorAction SilentlyContinue
                        $disabled = Get-ItemProperty -Path $path -Name DisabledByDefault -ErrorAction SilentlyContinue | Select-Object -ExpandProperty DisabledByDefault -ErrorAction SilentlyContinue
                    }
                    return [PSCustomObject]@{
                        Enabled            = $enabled
                        DisabledByDefault  = $disabled
                    }
                } -ArgumentList $regPath -ErrorAction Stop

                $results += [PSCustomObject]@{
                    ComputerName       = $server
                    Protocol           = $protocol
                    Role               = $role
                    Enabled            = $output.Enabled
                    DisabledByDefault  = $output.DisabledByDefault
                }
            } catch {
                Write-Verbose "  Error connecting to $server or reading $protocol ($role)"
                $results += [PSCustomObject]@{
                    ComputerName       = $server
                    Protocol           = $protocol
                    Role               = $role
                    Enabled            = "Error"
                    DisabledByDefault  = "Error"
                }
            }
        }
    }
}

$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$outputPath = "C:\Temp\TLS_Check_Result_$timestamp.csv"
$results | Export-Csv -NoTypeInformation -Path $outputPath

Write-Verbose "Results exported to $outputPath"

# End of Script
