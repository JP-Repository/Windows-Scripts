<#
.SYNOPSIS
    This script checks and enables PowerShell Remoting, ensures the WinRM service is running, and verifies the existence of the firewall rule for PowerShell Remoting on multiple servers.

.DESCRIPTION
    This script automates the process of ensuring PowerShell Remoting is enabled, the WinRM service is running, and the required firewall rule is in place for PowerShell Remoting. It logs the actions performed on each server in a CSV file.

.NOTES
    Script Name    : Enable-PSRemoting
    Version        : 0.1
    Author         : [Your Name]
    Approved By    : [Approver's Name]
    Date           : [Date]
    Purpose        : To ensure PowerShell Remoting is enabled, WinRM service is running, and firewall rules are correctly configured on multiple servers.

.PREREQUISITES
    - The script must be executed by a user with administrative privileges on the target servers.
    - PowerShell Remoting must be enabled on the local machine to execute commands remotely.
    - Target servers should be reachable over the network.

.PARAMETERS
    [Optional] Define any script parameters here if applicable.

.EXAMPLE
    .\Enable-PSRemoting.ps1
    This will run the script on the defined servers and log the actions in the specified CSV file.

#>

# Start of Script

# Define the output log file
$logFile = "C:\Scripts\PSRemoting_Log.csv"

# Check if the log file exists; if not, create it with headers
if (-not (Test-Path $logFile)) {
    "ServerName,Action,Status,Timestamp" | Out-File -FilePath $logFile
}

# Function to log actions
function Log-Action {
    param (
        [string]$ServerName,
        [string]$Action,
        [string]$Status
    )
    $timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    "$ServerName,$Action,$Status,$timestamp" | Out-File -FilePath $logFile -Append
}

# List of servers (use Get-Content for external file or define here)
$servers = @("localhost") # Replace "localhost" with server names or use Get-Content

# Loop through each server
foreach ($server in $servers) {
    Write-Host "Processing server: $server" -ForegroundColor Cyan

    try {
        # Check and enable PS-Remoting
        Write-Host "Checking PowerShell Remoting on $server..."
        $psRemotingEnabled = Test-WSMan -ComputerName $server -ErrorAction SilentlyContinue
        if (-not $psRemotingEnabled) {
            Write-Host "PowerShell Remoting is not enabled. Enabling it on $server..." -ForegroundColor Yellow
            Invoke-Command -ComputerName $server -ScriptBlock { Enable-PSRemoting -Force } -ErrorAction Stop
            Log-Action -ServerName $server -Action "Enable-PSRemoting" -Status "Success"
        } else {
            Write-Host "PowerShell Remoting is already enabled on $server." -ForegroundColor Green
            Log-Action -ServerName $server -Action "Enable-PSRemoting" -Status "Already Enabled"
        }

        # Ensure WinRM Service is running
        Write-Host "Checking WinRM Service on $server..."
        $winRMStatus = Invoke-Command -ComputerName $server -ScriptBlock {
            Get-Service -Name WinRM -ErrorAction SilentlyContinue
        }
        if ($winRMStatus.Status -ne "Running") {
            Write-Host "WinRM Service is not running. Starting it on $server..." -ForegroundColor Yellow
            Invoke-Command -ComputerName $server -ScriptBlock {
                Set-Service -Name WinRM -StartupType Automatic
                Start-Service -Name WinRM
            } -ErrorAction Stop
            Log-Action -ServerName $server -Action "Start-WinRMService" -Status "Success"
        } else {
            Write-Host "WinRM Service is already running on $server." -ForegroundColor Green
            Log-Action -ServerName $server -Action "Start-WinRMService" -Status "Already Running"
        }

        # Check for Firewall Rule
        Write-Host "Checking Firewall Rule on $server..."
        $firewallRuleExists = Invoke-Command -ComputerName $server -ScriptBlock {
            Get-NetFirewallRule -DisplayName "PowerShell Remoting" -ErrorAction SilentlyContinue
        }
        if (-not $firewallRuleExists) {
            Write-Host "Firewall rule is missing. Creating it on $server..." -ForegroundColor Yellow
            Invoke-Command -ComputerName $server -ScriptBlock {
                New-NetFirewallRule -Name "PowerShell Remoting" -DisplayName "PowerShell Remoting" -Enabled True -Profile Any -Action Allow -Direction Inbound -Protocol TCP -LocalPort 5985
            } -ErrorAction Stop
            Log-Action -ServerName $server -Action "Create-FirewallRule" -Status "Success"
        } else {
            Write-Host "Firewall rule already exists on $server." -ForegroundColor Green
            Log-Action -ServerName $server -Action "Create-FirewallRule" -Status "Already Exists"
        }

    } catch {
        Write-Host "Error processing $server: $_" -ForegroundColor Red
        Log-Action -ServerName $server -Action "Error" -Status $_.Exception.Message
    }
}

Write-Host "Script execution completed. Log file saved at: $logFile" -ForegroundColor Cyan

# End of Script
