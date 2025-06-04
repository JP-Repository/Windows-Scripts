<#
.SYNOPSIS
    Enables only TLS 1.2 and disables TLS 1.0 and TLS 1.1 on multiple remote servers.

.DESCRIPTION
    This script connects to each server listed in a text file and modifies the SCHANNEL registry entries
    to enable TLS 1.2 for both Client and Server, while disabling TLS 1.0 and TLS 1.1.
    The changes are logged and exported to a timestamped CSV file.

.NOTES
    Script Name    : Set_TLS12_Only.ps1
    Version        : 1.0
    Author         : [Your Name]
    Approved By    : [Approver's Name]
    Date           : 
    Purpose        : Secure remote servers by enforcing only TLS 1.2 support.

.PREREQUISITES
    - Remote PowerShell access enabled on target servers
    - User must have local admin rights on target servers
    - ServerList.txt must contain one server name per line
    - A reboot is required for changes to take effect

.PARAMETERS
    None

.EXAMPLE
    .\Set_TLS12_Only.ps1

#>

# Start of Script

$servers = Get-Content "C:\Temp\ServerList.txt"
$exportData = @()
$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$exportPath = "C:\Temp\TLS12_Setting_Result_$timestamp.csv"

foreach ($server in $servers) {
    Write-Host "Applying TLS 1.2 only on $server..." -ForegroundColor Yellow

    Invoke-Command -ComputerName $server -ScriptBlock {
        $result = [PSCustomObject]@{
            ComputerName          = $env:COMPUTERNAME
            TLS12_Client_Enabled  = $null
            TLS12_Server_Enabled  = $null
            TLS10_Client_Disabled = $null
            TLS10_Server_Disabled = $null
            TLS11_Client_Disabled = $null
            TLS11_Server_Disabled = $null
            Status                = "Attempted"
        }

        try {
            $base = "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols"

            $settings = @{
                "TLS 1.2\Client" = @{ Enabled = 1; DisabledByDefault = 0 }
                "TLS 1.2\Server" = @{ Enabled = 1; DisabledByDefault = 0 }
                "TLS 1.1\Client" = @{ Enabled = 0; DisabledByDefault = 1 }
                "TLS 1.1\Server" = @{ Enabled = 0; DisabledByDefault = 1 }
                "TLS 1.0\Client" = @{ Enabled = 0; DisabledByDefault = 1 }
                "TLS 1.0\Server" = @{ Enabled = 0; DisabledByDefault = 1 }
            }

            foreach ($key in $settings.Keys) {
                $fullPath = Join-Path $base $key
                if (-not (Test-Path $fullPath)) {
                    New-Item -Path $fullPath -Force | Out-Null
                }
                foreach ($prop in $settings[$key].Keys) {
                    New-ItemProperty -Path $fullPath -Name $prop -Value $settings[$key][$prop] -PropertyType DWORD -Force | Out-Null
                }
            }

            $result.TLS12_Client_Enabled  = 1
            $result.TLS12_Server_Enabled  = 1
            $result.TLS10_Client_Disabled = 1
            $result.TLS10_Server_Disabled = 1
            $result.TLS11_Client_Disabled = 1
            $result.TLS11_Server_Disabled = 1
            $result.Status                = "Success"
        } catch {
            $result.Status = "Error: $_"
        }

        return $result
    } -ErrorAction SilentlyContinue | ForEach-Object {
        $_.ComputerName = $server
        $exportData += $_
    }
}

$exportData | Export-Csv -Path $exportPath -NoTypeInformation
Write-Host "Exported results to $exportPath" -ForegroundColor Green

# End of Script
