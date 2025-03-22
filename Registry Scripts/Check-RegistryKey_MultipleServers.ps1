<#
.SYNOPSIS
    This script checks if specific registry paths exist on a list of servers and logs the results.

.DESCRIPTION
    This script automates the process of checking if certain registry paths exist on specified servers. It logs the results (whether the registry path exists or not) in a CSV file.

.NOTES
    Script Name    : Check-RegistryPaths
    Version        : 0.1
    Author         : [Your Name]
    Approved By    : [Approver's Name]
    Date           : [Date]
    Purpose        : To check the existence of specified registry paths on multiple servers and log the actions performed.

.PREREQUISITES
    - The script must be executed by a user with administrative privileges on the target servers.
    - PowerShell Remoting must be enabled on the target servers to run remote commands.

.PARAMETERS
    [Optional] Define any script parameters here if applicable.

.EXAMPLE
    .\Check-RegistryPaths.ps1
    This will check the specified registry paths on the list of servers and log the results in the specified CSV file.

#>

# Start of Script

# Define the log file
$logFile = "C:\Scripts\Registry_Check_Log.csv"

# Check if the log file exists; if not, create it with headers
if (-not (Test-Path $logFile)) {
    "ServerName,RegistryPath,RegistryKeyExists,Timestamp" | Out-File -FilePath $logFile
}

# Function to log actions
function Log-Action {
    param (
        [string]$ServerName,
        [string]$RegistryPath,
        [bool]$RegistryKeyExists
    )
    $timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    $status = if ($RegistryKeyExists) { "Exists" } else { "Does Not Exist" }
    "$ServerName,$RegistryPath,$status,$timestamp" | Out-File -FilePath $logFile -Append
}

# Define the registry paths to check
$registryPaths = @(
    "HKLM:\SOFTWARE\MyCompany\Settings",
    "HKCU:\Software\MyCompany\Settings"
)

# Get the list of servers to check (example: use domain controllers or a list of servers)
$servers = @("Server1", "Server2", "Server3")  # Modify this with actual server names or IPs

# Loop through each server
foreach ($server in $servers) {
    Write-Host "Checking registry keys on server: $server" -ForegroundColor Cyan

    foreach ($registryPath in $registryPaths) {
        try {
            # Check if the registry path exists on the server
            $keyExists = Invoke-Command -ComputerName $server -ScriptBlock {
                param ($path)
                Test-Path -Path $path
            } -ArgumentList $registryPath

            # Log the result
            Log-Action -ServerName $server -RegistryPath $registryPath -RegistryKeyExists $keyExists
            if ($keyExists) {
                Write-Host "Registry path $registryPath exists on $server." -ForegroundColor Green
            } else {
                Write-Host "Registry path $registryPath does not exist on $server." -ForegroundColor Red
            }
        } catch {
            Write-Host "Error checking registry path $registryPath on $server: $_" -ForegroundColor Red
            Log-Action -ServerName $server -RegistryPath $registryPath -RegistryKeyExists $false
        }
    }
}

Write-Host "Script execution completed. Log file saved at: $logFile" -ForegroundColor Cyan

# End of Script
