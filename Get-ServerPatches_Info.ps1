<#
.SYNOPSIS
    This Script will get Installed Patches Information for the mentioned Servers in a .csv file.
    Ensure to follow the steps mentioned in the description.

.DESCRIPTION
    This script retrieves installed patch information from a list of servers provided in a CSV file.
    The output file is saved under "C:\Temp" with the name "Installed_PatchesInfo" followed by the execution date.

.NOTES
    Script Name    : Get-ServerPatches_Info.ps1
    Version        : 0.2
    Author         : Jonathan Preetham
    Approved By    : [Approver's Name]
    Date           : 03/12/2023
    Purpose        : Retrieves installed patch information from multiple servers.

.PREREQUISITES
    - Create a .csv file named "ServerList.csv"
    - Column A1 should be labeled "Servername"
    - Enter the list of server names from A2 onwards
    - Save the CSV file in "C:\Temp"
    - Save this script in "C:\Temp"
    - Run PowerShell ISE as Administrator and execute the script

.PARAMETERS
    None

.EXAMPLE
    Open PowerShell ISE as Administrator and run the script:
    .\Get-ServerPatches_Info.ps1
#>

# Start of Script

# Importing Active Directory Module
Import-Module ActiveDirectory

# Importing Server Information from "ServerList.csv" File
$Servers = Import-Csv C:\Temp\ServerList.csv

# Progress Parameter
$Progress = @{
    Activity = 'Exporting Patched KB Information:'
    CurrentOperation = "Loading"
    Status = 'Importing Servers From .CSV File'
    PercentComplete = 0
}

# Creating an Array to Store Patch Information
$PatchInformation = @()

# Progress Parameter
Write-Progress @Progress
$i = 0

# Looping through each server
foreach($Server in $Servers){
    # Using "Get-Hotfix" to retrieve patch information
    $Patches = Get-Hotfix -ComputerName $Server.Servername
    
    # Updating Progress
    $i++
    [int]$Percentage = ($i / $Servers.Count)*100
    $Progress.CurrentOperation = "$Server"
    $Progress.Status = 'Fetching Patch Data From:'
    $Progress.PercentComplete = $Percentage
    
    Write-Progress @Progress
    Start-Sleep -Milliseconds 600

    # Storing Patch Information
    foreach ($Patch in $Patches) {
        $PatchInfo = New-Object PSObject
        $PatchInfo | Add-Member -MemberType NoteProperty -Name ComputerName -Value $Server.Servername
        $PatchInfo | Add-Member -MemberType NoteProperty -Name HotfixID -Value $Patch.HotfixID
        $PatchInfo | Add-Member -MemberType NoteProperty -Name InstallDate -Value $Patch.InstalledOn
        $PatchInformation += $PatchInfo
    }
}

# Exporting Patch Information to a CSV File
$PatchInformation | Export-Csv -Path "C:\Temp\Installed_PatchesInfo_$(get-date -f dd-MM-yyyy).csv" -NoTypeInformation

# End of Script
