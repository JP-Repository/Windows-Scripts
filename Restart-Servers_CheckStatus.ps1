<#
.SYNOPSIS
    Restarts multiple servers and checks their availability after the restart.

.DESCRIPTION
    This script reads a list of server names from a text file, restarts each server, 
    and then checks if the server is back online by testing its connectivity.

.NOTES
    Script Name    : Restart-Servers_CheckStatus.ps1
    Version        : 1.0
    Author         : [Your Name]
    Approved By    : [Approver's Name]
    Date           : [Date]

.PREREQUISITES
    - The user must have administrative privileges on the target servers.
    - Ensure PowerShell remoting is enabled on the target servers.

.PARAMETERS
    -ServerListFile: Path to the text file containing the list of server names (one per line).

.EXAMPLE
    .\RestartServersAndCheckStatus.ps1 -ServerListFile "C:\Temp\ServerList.txt"

    Restarts the servers listed in the specified file and checks their status.
#>

param (
    [Parameter(Mandatory = $true)]
    [string]$ServerListFile
)

# Read the list of servers from the file
if (!(Test-Path -Path $ServerListFile)) {
    Write-Error "The specified file '$ServerListFile' does not exist."
    exit
}

$Servers = Get-Content -Path $ServerListFile
if ($Servers.Count -eq 0) {
    Write-Error "The file '$ServerListFile' is empty."
    exit
}

# Initialize a results array
$Results = @()

foreach ($Server in $Servers) {
    try {
        Write-Output "Restarting server: $Server"

        # Restart the server
        Invoke-Command -ComputerName $Server -ScriptBlock { Restart-Computer -Force -Confirm:$false } -ErrorAction Stop

        # Wait for the server to go offline
        Write-Output "Waiting for $Server to go offline..."
        while (Test-Connection -ComputerName $Server -Quiet -Count 1) {
            Start-Sleep -Seconds 5
        }

        # Wait for the server to come back online
        Write-Output "Waiting for $Server to come back online..."
        while (!(Test-Connection -ComputerName $Server -Quiet -Count 1)) {
            Start-Sleep -Seconds 5
        }

        # Check if the server is reachable
        if (Test-Connection -ComputerName $Server -Quiet -Count 1) {
            $Results += [PSCustomObject]@{
                ServerName = $Server
                Status     = "Online"
            }
            Write-Output "$Server is back online."
        } else {
            $Results += [PSCustomObject]@{
                ServerName = $Server
                Status     = "Offline"
            }
            Write-Output "$Server is still offline."
        }
    } catch {
        # Handle errors
        $Results += [PSCustomObject]@{
            ServerName = $Server
            Status     = "Error: $_"
        }
        Write-Output "Failed to restart $Server. Error: $_"
    }
}

# Output the results
$Results | Format-Table -AutoSize

# Optional: Export results to a CSV file
$Results | Export-Csv -Path "C:\Temp\ServerRestartResults.csv" -NoTypeInformation
