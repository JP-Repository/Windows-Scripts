<#
.SYNOPSIS
    Reverts TLS settings on target servers to their original/default state by removing custom SCHANNEL registry keys.

.DESCRIPTION
    This script connects to remote servers listed in a text file and removes the registry entries
    under SCHANNEL for TLS 1.0, 1.1, and 1.2 protocols (Client and Server roles). 
    This effectively reverts any enforcement done by previous TLS hardening scripts.

.NOTES
    Script Name    : Revert_TLS_Settings.ps1
    Version        : 1.0
    Author         : [Your Name]
    Approved By    : [Approver's Name]
    Date           : 
    Purpose        : Revert TLS registry settings to original configuration (i.e., no hard enforcement via registry)

.PREREQUISITES
    - Remote PowerShell access enabled on target servers
    - Local admin rights on remote servers
    - ServerList.txt file with one server name per line
    - Reboot required for changes to take effect

.PARAMETERS
    None

.EXAMPLE
    .\Revert_TLS_Settings.ps1

#>

# Start of Script

$servers = Get-Content "C:\Temp\ServerList.txt"
$exportData = @()
$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$exportPath = "C:\Temp\TLS_Revert_Result_$timestamp.csv"

foreach ($server in $servers) {
    Write-Host "Reverting TLS settings on $server..." -ForegroundColor Yellow

    Invoke-Command -ComputerName $server -ScriptBlock {
        $result = [PSCustomObject]@{
            ComputerName = $env:COMPUTERNAME
            TLS10_Client_Removed = $false
            TLS10_Server_Removed = $false
            TLS11_Client_Removed = $false
            TLS11_Server_Removed = $false
            TLS12_Client_Removed = $false
            TLS12_Server_Removed = $false
            Status = "Attempted"
        }

        try {
            $paths = @(
                "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.0\Client",
                "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.0\Server",
                "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.1\Client",
                "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.1\Server",
                "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.2\Client",
                "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.2\Server"
            )

            foreach ($path in $paths) {
                if (Test-Path $path) {
                    Remove-Item -Path $path -Recurse -Force
                    switch -Wildcard ($path) {
                        "*TLS 1.0*Client" { $result.TLS10_Client_Removed = $true }
                        "*TLS 1.0*Server" { $result.TLS10_Server_Removed = $true }
                        "*TLS 1.1*Client" { $result.TLS11_Client_Removed = $true }
                        "*TLS 1.1*Server" { $result.TLS11_Server_Removed = $true }
                        "*TLS 1.2*Client" { $result.TLS12_Client_Removed = $true }
                        "*TLS 1.2*Server" { $result.TLS12_Server_Removed = $true }
                    }
                }
            }

            $result.Status = "Reverted"
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
