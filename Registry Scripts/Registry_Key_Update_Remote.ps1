<#
.SYNOPSIS
    Creates or updates specific registry keys on remote servers as per the requirements.

.DESCRIPTION
    This script reads a list of servers from a text file and creates or updates specific registry keys 
    on each server. The registry keys are defined in the script and include paths, value names, 
    and value data.

.NOTES
    Script Name    : Registry_Key_Update_Remote.ps1
    Version        : 0.1
    Author         : [Your Name]
    Approved By    : [Approver's Name]
    Date           : [Date]
    Purpose        : Automate the creation or update of registry keys on multiple servers.

.PREREQUISITES
    - PowerShell Remoting must be enabled on the target servers.
    - The executing user must have administrative privileges on the target servers.
    - A text file containing the list of server names (one per line).

.PARAMETERS
    -ServerList: Path to the text file containing the list of server names.

.EXAMPLE
    .\Registry_Key_Update_Remote.ps1 -ServerList "C:\Temp\ServerList.txt"
#>

param (
    [Parameter(Mandatory = $true)]
    [string]$ServerList
)

# Define registry paths and the value to set
$registryPaths = @(
    "HKLM:\Software\Microsoft\Cryptography\Wintrust\Config",
    "HKLM:\Software\Wow6432Node\Microsoft\Cryptography\Wintrust\Config"
)
$valueName = "EnableCertPaddingCheck"
$valueData = 1

# Read the list of servers from the provided text file
if (-Not (Test-Path -Path $ServerList)) {
    Write-Error "The server list file does not exist: $ServerList"
    exit
}

$servers = Get-Content -Path $ServerList

foreach ($server in $servers) {
    Write-Output "Processing server: $server"

    Invoke-Command -ComputerName $server -ScriptBlock {
        param ($registryPaths, $valueName, $valueData)

        foreach ($path in $registryPaths) {
            # Check if the registry path exists
            if (!(Test-Path -Path $path)) {
                Write-Output "Creating registry path: $path"
                New-Item -Path $path -Force | Out-Null
            }

            # Check if the registry value exists and set it
            if ((Get-ItemProperty -Path $path -Name $valueName -ErrorAction SilentlyContinue) -eq $null) {
                Write-Output "Creating registry value '$valueName' with data '$valueData' in $path"
                New-ItemProperty -Path $path -Name $valueName -Value $valueData -PropertyType DWord -Force | Out-Null
            } else {
                Write-Output "Registry value '$valueName' already exists in $path. Updating its value to '$valueData'."
                Set-ItemProperty -Path $path -Name $valueName -Value $valueData
            }
        }
    } -ArgumentList $registryPaths, $valueName, $valueData -ErrorAction Stop
}

Write-Output "Registry keys and values have been created/updated successfully on all servers."