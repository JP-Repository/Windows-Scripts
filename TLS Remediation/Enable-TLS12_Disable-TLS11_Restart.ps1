<#
.SYNOPSIS
    Remotely enables TLS 1.2, disables TLS 1.1, restarts servers, and verifies they come back online.

.DESCRIPTION
    This script performs TLS protocol hardening on remote Windows servers (typically Domain Controllers)
    by:
        - Enabling TLS 1.2 for both Client and Server SCHANNEL roles
        - Disabling TLS 1.1 for both Client and Server SCHANNEL roles
        - Restarting each target server to apply the changes
        - Checking that each server goes offline and then returns online successfully

    Target servers are read from a text file (one server name per line). Results are written to the
    console and exported to a CSV file for auditing.

.NOTES
    Script Name    : Enable-TLS12_Disable-TLS11_Restart.ps1
    Version        : 1.0
    Author         : Jonathan Preetham
    Approved By    : [Approver's Name]
    Date           : [Date]
    Purpose        : Standardize TLS configuration (enable TLS 1.2, disable TLS 1.1) across servers
                     and verify that they reboot and return to an online state.

.PREREQUISITES
    - PowerShell Remoting (WinRM) enabled and configured on target servers
    - Run the script with administrative privileges
    - Network connectivity to all target servers
    - Servers must allow remote commands via WinRM
    - A reboot is required on each server to apply TLS changes
    - Ensure the export directory (e.g. C:\Temp) exists or update the export path in the script

.PARAMETERS
    -ServerListFile <String>
        Path to a text file containing the list of server names (one server name per line).
        Example contents:
            DC01
            DC02
            APP-SRV01

.EXAMPLE
    PS C:\> .\Enable-TLS12_Disable-TLS11_Restart.ps1 -ServerListFile "C:\Temp\ServerList.txt"

    Runs the script against each server listed in ServerList.txt, updates TLS settings, restarts
    each server, waits for them to come back online, and exports the results to:
        C:\Temp\TLS_Update_And_Restart_Results.csv
#>

# Start of Script

[CmdletBinding()]
param (
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$ServerListFile
)

# Validate server list file
if (!(Test-Path -Path $ServerListFile)) {
    Write-Error "The specified file '$ServerListFile' does not exist."
    exit 1
}

$Servers = Get-Content -Path $ServerListFile

if ($Servers.Count -eq 0) {
    Write-Error "The file '$ServerListFile' is empty. Add at least one server name (one per line)."
    exit 1
}

# Define the TLS hardening script block
$TLSUpdateScriptBlock = {
    $basePath = "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols"

    # TLS 1.2 - Enable (Client & Server)
    New-Item -Path "$basePath\TLS 1.2\Client" -Force | Out-Null
    New-Item -Path "$basePath\TLS 1.2\Server" -Force | Out-Null

    Set-ItemProperty -Path "$basePath\TLS 1.2\Client" -Name "Enabled"           -Value 1 -Type DWord
    Set-ItemProperty -Path "$basePath\TLS 1.2\Client" -Name "DisabledByDefault" -Value 0 -Type DWord
    Set-ItemProperty -Path "$basePath\TLS 1.2\Server" -Name "Enabled"           -Value 1 -Type DWord
    Set-ItemProperty -Path "$basePath\TLS 1.2\Server" -Name "DisabledByDefault" -Value 0 -Type DWord

    # TLS 1.1 - Disable (Client & Server)
    New-Item -Path "$basePath\TLS 1.1\Client" -Force | Out-Null
    New-Item -Path "$basePath\TLS 1.1\Server" -Force | Out-Null

    Set-ItemProperty -Path "$basePath\TLS 1.1\Client" -Name "Enabled"           -Value 0 -Type DWord
    Set-ItemProperty -Path "$basePath\TLS 1.1\Client" -Name "DisabledByDefault" -Value 1 -Type DWord
    Set-ItemProperty -Path "$basePath\TLS 1.1\Server" -Name "Enabled"           -Value 0 -Type DWord
    Set-ItemProperty -Path "$basePath\TLS 1.1\Server" -Name "DisabledByDefault" -Value 1 -Type DWord

    Write-Output "TLS registry settings updated. Reboot required."
}

# Initialize results array
$Results = @()

foreach ($Server in $Servers) {
    if ([string]::IsNullOrWhiteSpace($Server)) {
        continue
    }

    Write-Host "Processing $Server..." -ForegroundColor Cyan

    try {
        # Apply TLS settings remotely
        Invoke-Command -ComputerName $Server -ScriptBlock $TLSUpdateScriptBlock -ErrorAction Stop
        Write-Host "TLS settings applied successfully on $Server." -ForegroundColor Green

        # Restart server
        Write-Host "Restarting $Server..." -ForegroundColor Yellow
        Invoke-Command -ComputerName $Server -ScriptBlock { Restart-Computer -Force -Confirm:$false } -ErrorAction Stop

        # Wait for server to go offline
        Write-Host "Waiting for $Server to go offline..."
        while (Test-Connection -ComputerName $Server -Quiet -Count 1) {
            Start-Sleep -Seconds 5
        }

        # Wait for server to come back online
        Write-Host "Waiting for $Server to come back online..."
        while (!(Test-Connection -ComputerName $Server -Quiet -Count 1)) {
            Start-Sleep -Seconds 5
        }

        # Confirm online status
        if (Test-Connection -ComputerName $Server -Quiet -Count 1) {
            Write-Host "$Server is back online." -ForegroundColor Green
            $Results += [PSCustomObject]@{
                ServerName = $Server
                TLSUpdate  = "Success"
                Restart    = "Success"
                Status     = "Online"
            }
        }
        else {
            Write-Host "$Server is still offline." -ForegroundColor Red
            $Results += [PSCustomObject]@{
                ServerName = $Server
                TLSUpdate  = "Success"
                Restart    = "Success"
                Status     = "Offline"
            }
        }
    }
    catch {
        Write-Host "Error processing $Server $_" -ForegroundColor Red
        $Results += [PSCustomObject]@{
            ServerName = $Server
            TLSUpdate  = "Failed"
            Restart    = "Failed"
            Status     = "Error: $_"
        }
    }
}

# Output and export the results
$Results | Format-Table -AutoSize

# NOTE: Ensure C:\Temp exists or change the path below as needed.
$Results | Export-Csv -Path "C:\Temp\TLS_Update_And_Restart_Results.csv" -NoTypeInformation

# End of Script
